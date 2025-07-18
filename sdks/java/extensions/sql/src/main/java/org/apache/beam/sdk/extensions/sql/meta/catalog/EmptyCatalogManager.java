/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.apache.beam.sdk.extensions.sql.meta.catalog;

import java.util.Map;
import org.apache.beam.sdk.extensions.sql.meta.provider.TableProvider;
import org.apache.beam.vendor.guava.v32_1_2_jre.com.google.common.collect.ImmutableMap;
import org.checkerframework.checker.nullness.qual.Nullable;

public class EmptyCatalogManager implements CatalogManager {
  private static final InMemoryCatalog EMPTY = new InMemoryCatalog("default", ImmutableMap.of());

  @Override
  public void useCatalog(String name) {
    if (!EMPTY.name().equalsIgnoreCase(name)) {
      throw new IllegalArgumentException("Catalog not found: " + name);
    }
  }

  @Override
  public Catalog currentCatalog() {
    return EMPTY;
  }

  @Override
  public @Nullable Catalog getCatalog(String name) {
    return name.equalsIgnoreCase(EMPTY.name()) ? EMPTY : null;
  }

  @Override
  public void dropCatalog(String name) {
    throw new UnsupportedOperationException(
        "ReadOnlyCatalogManager does not support removing a catalog");
  }

  @Override
  public void registerTableProvider(String name, TableProvider tableProvider) {
    throw new UnsupportedOperationException(
        "ReadOnlyCatalogManager does not support registering a table provider");
  }

  @Override
  public void createCatalog(String name, String type, Map<String, String> properties) {
    throw new UnsupportedOperationException(
        "ReadOnlyCatalogManager does not support catalog creation");
  }
}
