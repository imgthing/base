package rr_plugin

import (
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

type RPC struct {
	plugin *Plugin
	log    *zap.Logger
}

type LogRecord struct {
	Level   int8              `json:"level"`
	Message string            `json:"message"`
	Context map[string]string `json:"context"`
}

func (s *RPC) Log(record LogRecord, output *string) error {
	*output = record.Message

	fields := make([]zap.Field, 0, len(record.Context))

	for key, value := range record.Context {
		fields = append(fields, zap.String(key, value))
	}

	s.log.Log(zapcore.Level(record.Level), record.Message, fields...)

	return nil
}
