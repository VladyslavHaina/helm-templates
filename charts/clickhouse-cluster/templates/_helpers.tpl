{{- define "clickhouse-cluster.name" -}}
{{- default .Chart.Name .Values.cluster.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "clickhouse-cluster.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.cluster.name }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "clickhouse-cluster.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "clickhouse-cluster.labels" -}}
helm.sh/chart: {{ include "clickhouse-cluster.chart" . }}
app.kubernetes.io/name: {{ include "clickhouse-cluster.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "clickhouse-cluster.keeperName" -}}
{{- printf "%s-keeper" (include "clickhouse-cluster.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "clickhouse-cluster.otelName" -}}
{{- printf "%s-otel" (include "clickhouse-cluster.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
