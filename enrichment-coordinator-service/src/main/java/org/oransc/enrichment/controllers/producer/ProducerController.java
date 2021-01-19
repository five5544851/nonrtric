/*-
 * ========================LICENSE_START=================================
 * O-RAN-SC
 * %%
 * Copyright (C) 2020 Nordix Foundation
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

package org.oransc.enrichment.controllers.producer;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;

import io.swagger.annotations.Api;
import io.swagger.annotations.ApiOperation;
import io.swagger.annotations.ApiParam;
import io.swagger.annotations.ApiResponse;
import io.swagger.annotations.ApiResponses;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;

import org.oransc.enrichment.controllers.ErrorResponse;
import org.oransc.enrichment.controllers.VoidResponse;
import org.oransc.enrichment.exceptions.ServiceException;
import org.oransc.enrichment.repository.EiJob;
import org.oransc.enrichment.repository.EiJobs;
import org.oransc.enrichment.repository.EiProducer;
import org.oransc.enrichment.repository.EiProducers;
import org.oransc.enrichment.repository.EiType;
import org.oransc.enrichment.repository.EiTypes;
import org.oransc.enrichment.repository.ImmutableEiProducerRegistrationInfo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@SuppressWarnings("squid:S2629") // Invoke method(s) only conditionally
@RestController("ProducerController")
@Api(tags = {ProducerConsts.PRODUCER_API_NAME})
public class ProducerController {

    private static Gson gson = new GsonBuilder().create();

    @Autowired
    private EiJobs eiJobs;

    @Autowired
    private EiTypes eiTypes;

    @Autowired
    private EiProducers eiProducers;

    @GetMapping(path = ProducerConsts.API_ROOT + "/eitypes", produces = MediaType.APPLICATION_JSON_VALUE)
    @ApiOperation(value = "EI type identifiers", notes = "")
    @ApiResponses(
        value = { //
            @ApiResponse(
                code = 200,
                message = "EI type identifiers",
                response = String.class,
                responseContainer = "List"), //
        })
    public ResponseEntity<Object> getEiTypeIdentifiers( //
    ) {
        List<String> result = new ArrayList<>();
        for (EiType eiType : this.eiTypes.getAllEiTypes()) {
            result.add(eiType.getId());
        }

        return new ResponseEntity<>(gson.toJson(result), HttpStatus.OK);
    }

    @GetMapping(path = ProducerConsts.API_ROOT + "/eitypes/{eiTypeId}", produces = MediaType.APPLICATION_JSON_VALUE)
    @ApiOperation(value = "Individual EI type", notes = "")
    @ApiResponses(
        value = { //
            @ApiResponse(code = 200, message = "EI type", response = ProducerEiTypeInfo.class), //
            @ApiResponse(
                code = 404,
                message = "Enrichment Information type is not found",
                response = ErrorResponse.ErrorInfo.class)})
    public ResponseEntity<Object> getEiType( //
        @PathVariable("eiTypeId") String eiTypeId) {
        try {
            EiType t = this.eiTypes.getType(eiTypeId);
            ProducerEiTypeInfo info = toEiTypeInfo(t);
            return new ResponseEntity<>(gson.toJson(info), HttpStatus.OK);
        } catch (Exception e) {
            return ErrorResponse.create(e, HttpStatus.NOT_FOUND);
        }
    }

    @PutMapping(path = ProducerConsts.API_ROOT + "/eitypes/{eiTypeId}", produces = MediaType.APPLICATION_JSON_VALUE)
    @ApiResponses(
        value = { //
            @ApiResponse(code = 200, message = "Type updated", response = VoidResponse.class), //
            @ApiResponse(code = 201, message = "Type created", response = VoidResponse.class), //
            @ApiResponse(code = 400, message = "Bad request", response = ErrorResponse.ErrorInfo.class)})

    @ApiOperation(value = "Individual EI type", notes = "")
    public ResponseEntity<Object> putEiType( //
        @PathVariable("eiTypeId") String eiTypeId, @RequestBody ProducerEiTypeInfo registrationInfo) {

        EiType previousDefinition = this.eiTypes.get(eiTypeId);
        if (registrationInfo.jobDataSchema == null) {
            return ErrorResponse.create("No schema provided", HttpStatus.BAD_REQUEST);
        }
        this.eiTypes.put(new EiType(eiTypeId, registrationInfo.jobDataSchema));
        return new ResponseEntity<>(previousDefinition == null ? HttpStatus.CREATED : HttpStatus.OK);
    }

    @DeleteMapping(path = ProducerConsts.API_ROOT + "/eitypes/{eiTypeId}", produces = MediaType.APPLICATION_JSON_VALUE)
    @ApiOperation(value = "Individual EI type", notes = "")
    @ApiResponses(
        value = { //
            @ApiResponse(code = 200, message = "Not used", response = VoidResponse.class),
            @ApiResponse(code = 204, message = "Producer deleted", response = VoidResponse.class),
            @ApiResponse(
                code = 404,
                message = "Enrichment Information type is not found",
                response = ErrorResponse.ErrorInfo.class),
            @ApiResponse(
                code = 406,
                message = "The Enrichment Information type has one or several active producers",
                response = ErrorResponse.ErrorInfo.class)})
    public ResponseEntity<Object> deleteEiType( //
        @PathVariable("eiTypeId") String eiTypeId) {

        EiType type = this.eiTypes.get(eiTypeId);
        if (type == null) {
            return ErrorResponse.create("EI type not found", HttpStatus.NOT_FOUND);
        }
        if (!this.eiProducers.getProducersForType(type).isEmpty()) {
            String firstProducerId = this.eiProducers.getProducersForType(type).iterator().next().getId();
            return ErrorResponse.create("The type has active producers: " + firstProducerId, HttpStatus.NOT_ACCEPTABLE);
        }
        this.eiTypes.remove(type);
        return new ResponseEntity<>(HttpStatus.NO_CONTENT);
    }

    @GetMapping(path = ProducerConsts.API_ROOT + "/eiproducers", produces = MediaType.APPLICATION_JSON_VALUE)
    @ApiOperation(value = "EI producer identifiers", notes = "")
    @ApiResponses(
        value = { //
            @ApiResponse(
                code = 200,
                message = "EI producer identifiers",
                response = String.class,
                responseContainer = "List"), //
        })
    public ResponseEntity<Object> getEiProducerIdentifiers( //
        @ApiParam(
            name = "ei_type_id",
            required = false,
            value = "If given, only the producers for the EI Data type is returned.") //
        @RequestParam(name = "ei_type_id", required = false) String typeId //
    ) {
        List<String> result = new ArrayList<>();
        for (EiProducer eiProducer : typeId == null ? this.eiProducers.getAllProducers()
            : this.eiProducers.getProducersForType(typeId)) {
            result.add(eiProducer.getId());
        }

        return new ResponseEntity<>(gson.toJson(result), HttpStatus.OK);
    }

    @GetMapping(
        path = ProducerConsts.API_ROOT + "/eiproducers/{eiProducerId}",
        produces = MediaType.APPLICATION_JSON_VALUE)
    @ApiOperation(value = "Individual EI producer", notes = "")
    @ApiResponses(
        value = { //
            @ApiResponse(code = 200, message = "EI producer", response = ProducerRegistrationInfo.class), //
            @ApiResponse(
                code = 404,
                message = "Enrichment Information producer is not found",
                response = ErrorResponse.ErrorInfo.class)})
    public ResponseEntity<Object> getEiProducer( //
        @PathVariable("eiProducerId") String eiProducerId) {
        try {
            EiProducer p = this.eiProducers.getProducer(eiProducerId);
            ProducerRegistrationInfo info = toEiProducerRegistrationInfo(p);
            return new ResponseEntity<>(gson.toJson(info), HttpStatus.OK);
        } catch (Exception e) {
            return ErrorResponse.create(e, HttpStatus.NOT_FOUND);
        }
    }

    @GetMapping(
        path = ProducerConsts.API_ROOT + "/eiproducers/{eiProducerId}/eijobs",
        produces = MediaType.APPLICATION_JSON_VALUE)
    @ApiOperation(value = "EI job definitions", notes = "EI job definitions for one EI producer")
    @ApiResponses(
        value = { //
            @ApiResponse(
                code = 200,
                message = "EI producer",
                response = ProducerJobInfo.class,
                responseContainer = "List"), //
            @ApiResponse(
                code = 404,
                message = "Enrichment Information producer is not found",
                response = ErrorResponse.ErrorInfo.class)})
    public ResponseEntity<Object> getEiProducerJobs( //
        @PathVariable("eiProducerId") String eiProducerId) {
        try {
            EiProducer producer = this.eiProducers.getProducer(eiProducerId);
            Collection<ProducerJobInfo> producerJobs = new ArrayList<>();
            for (EiType type : producer.getEiTypes()) {
                for (EiJob eiJob : this.eiJobs.getJobsForType(type)) {
                    ProducerJobInfo request = new ProducerJobInfo(eiJob);
                    producerJobs.add(request);
                }
            }

            return new ResponseEntity<>(gson.toJson(producerJobs), HttpStatus.OK);
        } catch (Exception e) {
            return ErrorResponse.create(e, HttpStatus.NOT_FOUND);
        }
    }

    @GetMapping(
        path = ProducerConsts.API_ROOT + "/eiproducers/{eiProducerId}/status",
        produces = MediaType.APPLICATION_JSON_VALUE)
    @ApiOperation(value = "EI producer status")
    @ApiResponses(
        value = { //
            @ApiResponse(code = 200, message = "EI producer status", response = ProducerStatusInfo.class), //
            @ApiResponse(
                code = 404,
                message = "Enrichment Information producer is not found",
                response = ErrorResponse.ErrorInfo.class)})
    public ResponseEntity<Object> getEiProducerStatus( //
        @PathVariable("eiProducerId") String eiProducerId) {
        try {
            EiProducer producer = this.eiProducers.getProducer(eiProducerId);
            return new ResponseEntity<>(gson.toJson(producerStatusInfo(producer)), HttpStatus.OK);
        } catch (Exception e) {
            return ErrorResponse.create(e, HttpStatus.NOT_FOUND);
        }
    }

    private ProducerStatusInfo producerStatusInfo(EiProducer producer) {
        ProducerStatusInfo.OperationalState opState =
            producer.isAvailable() ? ProducerStatusInfo.OperationalState.ENABLED
                : ProducerStatusInfo.OperationalState.DISABLED;
        return new ProducerStatusInfo(opState);
    }

    @PutMapping(
        path = ProducerConsts.API_ROOT + "/eiproducers/{eiProducerId}", //
        produces = MediaType.APPLICATION_JSON_VALUE)
    @ApiOperation(value = "Individual EI producer", notes = "")
    @ApiResponses(
        value = { //
            @ApiResponse(code = 201, message = "Producer created", response = VoidResponse.class), //
            @ApiResponse(code = 200, message = "Producer updated", response = VoidResponse.class)} //
    )
    public ResponseEntity<Object> putEiProducer( //
        @PathVariable("eiProducerId") String eiProducerId, //
        @RequestBody ProducerRegistrationInfo registrationInfo) {
        try {
            EiProducer previousDefinition = this.eiProducers.get(eiProducerId);
            this.eiProducers.registerProducer(toEiProducerRegistrationInfo(eiProducerId, registrationInfo));
            return new ResponseEntity<>(previousDefinition == null ? HttpStatus.CREATED : HttpStatus.OK);
        } catch (Exception e) {
            return ErrorResponse.create(e, HttpStatus.NOT_FOUND);
        }
    }

    @DeleteMapping(
        path = ProducerConsts.API_ROOT + "/eiproducers/{eiProducerId}",
        produces = MediaType.APPLICATION_JSON_VALUE)
    @ApiOperation(value = "Individual EI producer", notes = "")
    @ApiResponses(
        value = { //
            @ApiResponse(code = 200, message = "Not used", response = VoidResponse.class),
            @ApiResponse(code = 204, message = "Producer deleted", response = VoidResponse.class),
            @ApiResponse(code = 404, message = "Producer is not found", response = ErrorResponse.ErrorInfo.class)})
    public ResponseEntity<Object> deleteEiProducer(@PathVariable("eiProducerId") String eiProducerId) {
        try {
            final EiProducer producer = this.eiProducers.getProducer(eiProducerId);
            this.eiProducers.deregisterProducer(producer);
            return new ResponseEntity<>(HttpStatus.NO_CONTENT);
        } catch (Exception e) {
            return ErrorResponse.create(e, HttpStatus.NOT_FOUND);
        }
    }

    private ProducerRegistrationInfo toEiProducerRegistrationInfo(EiProducer p) {
        Collection<String> types = new ArrayList<>();
        for (EiType type : p.getEiTypes()) {
            types.add(type.getId());
        }
        return new ProducerRegistrationInfo(types, p.getJobCallbackUrl(), p.getProducerSupervisionCallbackUrl());
    }

    private ProducerEiTypeInfo toEiTypeInfo(EiType t) {
        return new ProducerEiTypeInfo(t.getJobDataSchema());
    }

    private EiProducers.EiProducerRegistrationInfo toEiProducerRegistrationInfo(String eiProducerId,
        ProducerRegistrationInfo info) throws ServiceException {
        Collection<EiType> supportedTypes = new ArrayList<>();
        for (String typeId : info.supportedTypeIds) {
            EiType type = this.eiTypes.getType(typeId);
            supportedTypes.add(type);
        }

        return ImmutableEiProducerRegistrationInfo.builder() //
            .id(eiProducerId) //
            .jobCallbackUrl(info.jobCallbackUrl) //
            .producerSupervisionCallbackUrl(info.producerSupervisionCallbackUrl) //
            .supportedTypes(supportedTypes) //
            .build();
    }

}
