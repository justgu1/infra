{{- define "job-base.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "job-base.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{ include "job-base.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "job-base.selectorLabels" -}}
app.kubernetes.io/name: {{ include "job-base.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "job-base.secretName" -}}
{{ include "job-base.fullname" . }}-secrets
{{- end }}

{{- define "job-base.configMapName" -}}
{{ include "job-base.fullname" . }}-config
{{- end }}
