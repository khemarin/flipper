/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * @format
 */

import * as React from 'react';
import {
  createState,
  useLogger,
  usePlugin,
  useValue,
  _SandyPluginDefinition,
  PluginClient,
  DevicePluginClient,
} from 'flipper-plugin';
import {useEffect} from 'react';
import {
  BaseAction,
  FlipperDevicePlugin,
  FlipperPlugin,
  Props as PluginProps,
} from '../plugin';
import {useStore} from './useStore';
import {setStaticView, StaticView} from '../reducers/connections';
import {getStore} from '../store';
import {setActiveNotifications} from '../reducers/notifications';
import BaseDevice from '../devices/BaseDevice';

export type SandyPluginModule = ConstructorParameters<
  typeof _SandyPluginDefinition
>[1];

export function createSandyPluginWrapper<S, A extends BaseAction, P>(
  Plugin: typeof FlipperPlugin | typeof FlipperDevicePlugin,
): SandyPluginModule {
  const isDevicePlugin = Plugin.prototype instanceof FlipperDevicePlugin;
  function legacyPluginWrapper(client: PluginClient | DevicePluginClient) {
    const store = getStore();
    const appClient = isDevicePlugin
      ? undefined
      : (client as PluginClient<any, any>);

    const instanceRef = React.createRef<FlipperPlugin<S, A, P> | null>();
    const persistedState = createState<P>(Plugin.defaultPersistedState);
    const deeplink = createState<unknown>();

    client.onDeepLink((link) => {
      deeplink.set(link);
    });

    appClient?.onUnhandledMessage((event, params) => {
      if (Plugin.persistedStateReducer) {
        persistedState.set(
          Plugin.persistedStateReducer(persistedState.get(), event, params),
        );
      }
    });

    if (
      Plugin.persistedStateReducer ||
      Plugin.exportPersistedState ||
      Plugin.defaultPersistedState
    ) {
      client.onExport(async (idler, onStatusMessage) => {
        const state = Plugin.exportPersistedState
          ? await Plugin.exportPersistedState(
              isDevicePlugin
                ? undefined
                : (method: string, params: any) =>
                    // TODO: Fix this the next time the file is edited.
                    // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
                    appClient!.send(method, params),
              persistedState.get(),
              undefined, // passing an undefined Store is safe, as no plugin actually uses this param
              idler,
              onStatusMessage,
              isDevicePlugin
                ? undefined
                : // TODO: Fix this the next time the file is edited.
                  // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
                  (method: string) => appClient!.supportsMethod(method),
            )
          : persistedState.get();
        // respect custom serialization
        return Plugin.serializePersistedState
          ? await Plugin.serializePersistedState(
              state,
              onStatusMessage,
              idler,
              Plugin.id,
            )
          : state;
      });

      client.onImport((data) => {
        if (Plugin.deserializePersistedState) {
          data = Plugin.deserializePersistedState(data);
        }
        persistedState.set(data);
      });
    }

    if (Plugin.keyboardActions) {
      function executeKeyboardAction(action: string) {
        instanceRef?.current?.onKeyboardAction?.(action);
      }

      client.addMenuEntry(
        ...Plugin.keyboardActions.map((def) => {
          if (typeof def === 'string') {
            return {
              action: def,
              handler() {
                executeKeyboardAction(def);
              },
            };
          } else {
            const {action, label, accelerator} = def;
            return {
              label,
              accelerator,
              handler() {
                executeKeyboardAction(action);
              },
            };
          }
        }),
      );
    }

    if (Plugin.getActiveNotifications && !isDevicePlugin) {
      const unsub = persistedState.subscribe((state) => {
        try {
          // TODO: Fix this the next time the file is edited.
          // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
          const notifications = Plugin.getActiveNotifications!(state);
          store.dispatch(
            setActiveNotifications({
              notifications,
              // TODO: Fix this the next time the file is edited.
              // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
              client: appClient!.appId,
              pluginId: Plugin.id,
            }),
          );
        } catch (e) {
          console.error(
            'Failed to compute notifications for plugin ' + Plugin.id,
            e,
          );
        }
      });
      client.onDestroy(unsub);
    }

    return {
      instanceRef,
      device: client.device,
      persistedState,
      deeplink,
      selectPlugin: client.selectPlugin,
      setPersistedState(state: Partial<P>) {
        persistedState.set({...persistedState.get(), ...state});
      },
      get appId() {
        return appClient?.appId;
      },
      get appName() {
        return appClient?.appName ?? null;
      },
      get isArchived() {
        return client.device.isArchived;
      },
      setStaticView(payload: StaticView) {
        store.dispatch(setStaticView(payload));
      },
    };
  }

  function Component() {
    const instance = usePlugin(legacyPluginWrapper);
    const logger = useLogger();
    const persistedState = useValue(instance.persistedState);
    const deepLinkPayload = useValue(instance.deeplink);
    const settingsState = useStore((state) => state.settingsState);

    const target = isDevicePlugin
      ? // in the client, all Device's are BaseDevice, so this is safe..
        (instance.device as BaseDevice)
      : // eslint-disable-next-line
        useStore((state) => state.connections.clients.get(instance.appId!));
    if (!target) {
      throw new Error('Illegal state: missing target');
    }

    useEffect(
      function triggerInitAndTeardown() {
        // TODO: Fix this the next time the file is edited.
        // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
        const ref = instance.instanceRef.current!;
        ref._init();
        return () => {
          ref._teardown();
        };
      },
      [instance.instanceRef],
    );

    const props: PluginProps<P> = {
      logger,
      persistedState,
      deepLinkPayload,
      settingsState,
      target,
      setPersistedState: instance.setPersistedState,
      selectPlugin: instance.selectPlugin,
      isArchivedDevice: instance.isArchived,
      selectedApp: instance.appName,
      setStaticView: instance.setStaticView,
      // @ts-ignore ref is not on Props
      ref: instance.instanceRef,
    };

    return React.createElement(Plugin, props);
  }

  return isDevicePlugin
    ? {devicePlugin: legacyPluginWrapper, Component}
    : {
        plugin: legacyPluginWrapper,
        Component,
      };
}
