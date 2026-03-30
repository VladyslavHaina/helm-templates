{{- define "observability-stack.name" -}}
{{- default .Chart.Name .Values.stack.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "observability-stack.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.stack.name }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "observability-stack.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "observability-stack.labels" -}}
helm.sh/chart: {{ include "observability-stack.chart" . }}
app.kubernetes.io/name: {{ include "observability-stack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "observability-stack.otelName" -}}
{{- printf "%s-otel-collector" (include "observability-stack.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "observability-stack.uiName" -}}
{{- printf "%s-ui" (include "observability-stack.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "observability-stack.mongoName" -}}
{{- printf "%s-mongodb" (include "observability-stack.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
