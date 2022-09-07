/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

package com.facebook.flipper.plugins.uidebugger.common

@kotlinx.serialization.Serializable
class Node() {
  var id: String? = null
  var name: String? = null
  var attributes: Map<String, InspectableObject> = mapOf()
  var children: List<Node>? = null
}
