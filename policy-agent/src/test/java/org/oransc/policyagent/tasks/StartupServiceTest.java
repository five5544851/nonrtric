/*-
 * ========================LICENSE_START=================================
 * O-RAN-SC
 * %%
 * Copyright (C) 2019 Nordix Foundation
 * %%
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * ========================LICENSE_END===================================
 */

package org.oransc.policyagent.tasks;

import static org.assertj.core.api.Assertions.assertThat;
import static org.awaitility.Awaitility.await;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.oransc.policyagent.repository.Ric.RicState.ACTIVE;
import static org.oransc.policyagent.repository.Ric.RicState.NOT_REACHABLE;

import java.util.Vector;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.runner.RunWith;
import org.mockito.Mock;
import org.mockito.junit.MockitoJUnitRunner;
import org.mockito.junit.jupiter.MockitoExtension;
import org.oransc.policyagent.clients.A1Client;
import org.oransc.policyagent.configuration.ApplicationConfig;
import org.oransc.policyagent.configuration.ImmutableRicConfig;
import org.oransc.policyagent.configuration.RicConfig;
import org.oransc.policyagent.repository.PolicyTypes;
import org.oransc.policyagent.repository.Ric;
import org.oransc.policyagent.repository.Rics;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

@ExtendWith(MockitoExtension.class)
@RunWith(MockitoJUnitRunner.class)
public class StartupServiceTest {
    private static final String FIRST_RIC_NAME = "first";
    private static final String FIRST_RIC_URL = "firstUrl";
    private static final String SECOND_RIC_NAME = "second";
    private static final String SECOND_RIC_URL = "secondUrl";
    private static final String MANAGED_NODE_A = "nodeA";
    private static final String MANAGED_NODE_B = "nodeB";
    private static final String MANAGED_NODE_C = "nodeC";

    private static final String POLICY_TYPE_1_NAME = "type1";
    private static final String POLICY_TYPE_2_NAME = "type2";
    private static final String POLICY_ID_1 = "policy1";
    private static final String POLICY_ID_2 = "policy2";

    @Mock
    ApplicationConfig appConfigMock;

    @Mock
    A1Client a1ClientMock;

    @Test
    public void startup_allOk() {
        Vector<RicConfig> ricConfigs = new Vector<>(2);
        ricConfigs.add(getRicConfig(FIRST_RIC_NAME, FIRST_RIC_URL, MANAGED_NODE_A));
        ricConfigs.add(getRicConfig(SECOND_RIC_NAME, SECOND_RIC_URL, MANAGED_NODE_B, MANAGED_NODE_C));
        when(appConfigMock.getRicConfigs()).thenReturn(ricConfigs);

        Flux<String> fluxType1 = Flux.just(POLICY_TYPE_1_NAME);
        Flux<String> fluxType2 = Flux.just(POLICY_TYPE_2_NAME);
        when(a1ClientMock.getPolicyTypeIdentities(anyString())).thenReturn(fluxType1)
            .thenReturn(fluxType1.concatWith(fluxType2));
        Flux<String> policies = Flux.just(new String[] {POLICY_ID_1, POLICY_ID_2});
        when(a1ClientMock.getPolicyIdentities(anyString())).thenReturn(policies);
        when(a1ClientMock.deletePolicy(anyString(), anyString())).thenReturn(Mono.empty());

        Rics rics = new Rics();
        PolicyTypes policyTypes = new PolicyTypes();
        StartupService serviceUnderTest = new StartupService(appConfigMock, rics, policyTypes, a1ClientMock);

        serviceUnderTest.startup();

        await().untilAsserted(() -> assertThat(policyTypes.size()).isEqualTo(2));

        verify(a1ClientMock).getPolicyTypeIdentities(FIRST_RIC_URL);
        verify(a1ClientMock).deletePolicy(FIRST_RIC_URL, POLICY_ID_1);
        verify(a1ClientMock).deletePolicy(FIRST_RIC_URL, POLICY_ID_2);

        verify(a1ClientMock).getPolicyTypeIdentities(SECOND_RIC_URL);
        verify(a1ClientMock).deletePolicy(SECOND_RIC_URL, POLICY_ID_1);
        verify(a1ClientMock).deletePolicy(SECOND_RIC_URL, POLICY_ID_2);

        assertTrue(policyTypes.contains(POLICY_TYPE_1_NAME), POLICY_TYPE_1_NAME + " not added to PolicyTypes.");
        assertTrue(policyTypes.contains(POLICY_TYPE_2_NAME), POLICY_TYPE_2_NAME + " not added to PolicyTypes.");
        assertEquals(2, rics.size(), "Correct number of Rics not added to Rics");

        Ric firstRic = rics.get(FIRST_RIC_NAME);
        assertNotNull(firstRic, "Ric " + FIRST_RIC_NAME + " not added to repository");
        assertEquals(FIRST_RIC_NAME, firstRic.name(), FIRST_RIC_NAME + " not added to Rics");
        assertEquals(ACTIVE, firstRic.state(), "Not correct state for ric " + FIRST_RIC_NAME);
        assertEquals(1, firstRic.getSupportedPolicyTypes().size(),
            "Not correct no of types supported for ric " + FIRST_RIC_NAME);
        assertTrue(firstRic.isSupportingType(POLICY_TYPE_1_NAME),
            POLICY_TYPE_1_NAME + " not supported by ric " + FIRST_RIC_NAME);
        assertEquals(1, firstRic.getManagedNodes().size(), "Not correct no of managed nodes for ric " + FIRST_RIC_NAME);
        assertTrue(firstRic.isManaging(MANAGED_NODE_A), MANAGED_NODE_A + " not managed by ric " + FIRST_RIC_NAME);

        Ric secondRic = rics.get(SECOND_RIC_NAME);
        assertNotNull(secondRic, "Ric " + SECOND_RIC_NAME + " not added to repository");
        assertEquals(SECOND_RIC_NAME, secondRic.name(), SECOND_RIC_NAME + " not added to Rics");
        assertEquals(ACTIVE, secondRic.state(), "Not correct state for " + SECOND_RIC_NAME);
        assertEquals(2, secondRic.getSupportedPolicyTypes().size(),
            "Not correct no of types supported for ric " + SECOND_RIC_NAME);
        assertTrue(secondRic.isSupportingType(POLICY_TYPE_1_NAME),
            POLICY_TYPE_1_NAME + " not supported by ric " + SECOND_RIC_NAME);
        assertTrue(secondRic.isSupportingType(POLICY_TYPE_2_NAME),
            POLICY_TYPE_2_NAME + " not supported by ric " + SECOND_RIC_NAME);
        assertEquals(2, secondRic.getManagedNodes().size(),
            "Not correct no of managed nodes for ric " + SECOND_RIC_NAME);
        assertTrue(secondRic.isManaging(MANAGED_NODE_B), MANAGED_NODE_B + " not managed by ric " + SECOND_RIC_NAME);
        assertTrue(secondRic.isManaging(MANAGED_NODE_C), MANAGED_NODE_C + " not managed by ric " + SECOND_RIC_NAME);
    }

    @Test
    public void startup_unableToConnectToGetTypes() {
        Vector<RicConfig> ricConfigs = new Vector<>(2);
        ricConfigs.add(getRicConfig(FIRST_RIC_NAME, FIRST_RIC_URL, MANAGED_NODE_A));
        ricConfigs.add(getRicConfig(SECOND_RIC_NAME, SECOND_RIC_URL, MANAGED_NODE_B, MANAGED_NODE_C));
        when(appConfigMock.getRicConfigs()).thenReturn(ricConfigs);

        Flux<String> fluxType1 = Flux.just(POLICY_TYPE_1_NAME);
        doReturn(Flux.error(new Exception("Unable to contact ric.")), fluxType1).when(a1ClientMock)
            .getPolicyTypeIdentities(anyString());

        Flux<String> policies = Flux.just(new String[] {POLICY_ID_1, POLICY_ID_2});
        doReturn(policies).when(a1ClientMock).getPolicyIdentities(anyString());
        when(a1ClientMock.deletePolicy(anyString(), anyString())).thenReturn(Mono.empty());

        Rics rics = new Rics();
        PolicyTypes policyTypes = new PolicyTypes();
        StartupService serviceUnderTest = new StartupService(appConfigMock, rics, policyTypes, a1ClientMock);

        serviceUnderTest.startup();

        verify(a1ClientMock).deletePolicy(SECOND_RIC_URL, POLICY_ID_1);
        verify(a1ClientMock).deletePolicy(SECOND_RIC_URL, POLICY_ID_2);

        assertEquals(NOT_REACHABLE, rics.get(FIRST_RIC_NAME).state(), "Not correct state for " + FIRST_RIC_NAME);

        assertEquals(ACTIVE, rics.get(SECOND_RIC_NAME).state(), "Not correct state for " + SECOND_RIC_NAME);
    }

    @Test
    public void startup_unableToConnectToGetPolicies() {
        Vector<RicConfig> ricConfigs = new Vector<>(2);
        ricConfigs.add(getRicConfig(FIRST_RIC_NAME, FIRST_RIC_URL, MANAGED_NODE_A));
        ricConfigs.add(getRicConfig(SECOND_RIC_NAME, SECOND_RIC_URL, MANAGED_NODE_B, MANAGED_NODE_C));
        when(appConfigMock.getRicConfigs()).thenReturn(ricConfigs);

        Flux<String> fluxType1 = Flux.just(POLICY_TYPE_1_NAME);
        Flux<String> fluxType2 = Flux.just(POLICY_TYPE_2_NAME);
        when(a1ClientMock.getPolicyTypeIdentities(anyString())).thenReturn(fluxType1)
            .thenReturn(fluxType1.concatWith(fluxType2));
        Flux<String> policies = Flux.just(new String[] {POLICY_ID_1, POLICY_ID_2});
        doReturn(Flux.error(new Exception("Unable to contact ric.")), policies).when(a1ClientMock)
            .getPolicyIdentities(anyString());
        when(a1ClientMock.deletePolicy(anyString(), anyString())).thenReturn(Mono.empty());

        Rics rics = new Rics();
        PolicyTypes policyTypes = new PolicyTypes();
        StartupService serviceUnderTest = new StartupService(appConfigMock, rics, policyTypes, a1ClientMock);

        serviceUnderTest.startup();

        verify(a1ClientMock).deletePolicy(SECOND_RIC_URL, POLICY_ID_1);
        verify(a1ClientMock).deletePolicy(SECOND_RIC_URL, POLICY_ID_2);

        assertEquals(NOT_REACHABLE, rics.get(FIRST_RIC_NAME).state(), "Not correct state for " + FIRST_RIC_NAME);

        assertEquals(ACTIVE, rics.get(SECOND_RIC_NAME).state(), "Not correct state for " + SECOND_RIC_NAME);
    }

    private RicConfig getRicConfig(String name, String baseUrl, String... nodeNames) {
        Vector<String> managedNodes = new Vector<String>(1);
        for (String nodeName : nodeNames) {
            managedNodes.add(nodeName);
        }
        ImmutableRicConfig ricConfig = ImmutableRicConfig.builder() //
            .name(name) //
            .managedElementIds(managedNodes) //
            .baseUrl(baseUrl) //
            .build();
        return ricConfig;
    }
}