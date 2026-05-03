{{- define "vision.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "vision.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "vision.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Resolve an internal service hostname by key.
If .Values.serviceNames.<key> is set, that override is used (for docker-style parity).
Otherwise, falls back to <release-fullname>-<key>.
Usage: {{ include "vision.serviceName" (dict "root" . "key" "mdm-source") }}
*/}}
{{- define "vision.serviceName" -}}
{{- $root := index . "root" -}}
{{- $key := index . "key" -}}
{{- $serviceNames := default dict $root.Values.serviceNames -}}
{{- $override := index $serviceNames $key -}}
{{- if $override -}}
{{- $override -}}
{{- else -}}
{{- printf "%s-%s" (include "vision.fullname" $root) $key -}}
{{- end -}}
{{- end -}}
