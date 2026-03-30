{{- define "flink-jobs.name" -}}
{{- default .Chart.Name .Values.cluster.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "flink-jobs.fullname" -}}
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

{{- define "flink-jobs.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "flink-jobs.labels" -}}
helm.sh/chart: {{ include "flink-jobs.chart" . }}
app.kubernetes.io/name: {{ include "flink-jobs.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "flink-jobs.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "flink-jobs.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
