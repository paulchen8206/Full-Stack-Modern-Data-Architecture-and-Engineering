package com.example.realtime.serde;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.flink.api.common.serialization.DeserializationSchema;
import org.apache.flink.api.common.typeinfo.TypeInformation;

import java.io.IOException;

public class JsonDeserializationSchema<T> implements DeserializationSchema<T> {

    private final Class<T> targetType;
    private transient ObjectMapper objectMapper;

    public JsonDeserializationSchema(Class<T> targetType) {
        this.targetType = targetType;
    }

    @Override
    public T deserialize(byte[] message) throws IOException {
        if (objectMapper == null) {
            objectMapper = new ObjectMapper();
        }
        return objectMapper.readValue(message, targetType);
    }

    @Override
    public boolean isEndOfStream(T nextElement) {
        return false;
    }

    @Override
    public TypeInformation<T> getProducedType() {
        return TypeInformation.of(targetType);
    }
}
