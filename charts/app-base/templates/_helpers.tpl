{{/*
Expand the name of the chart.
*/}}
{{- define "app-base.name" -}}
{{- default .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Full name — used for all resource names.
*/}}
{{- define "app-base.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "app-base.labels" -}}
helm.sh/chart: {{ printf "%s-%s" (include "app-base.name" .) .Chart.Version }}
{{ include "app-base.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "app-base.selectorLabels" -}}
app.kubernetes.io/name: {{ include "app-base.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Secret name — used for envFrom secretRef
*/}}
{{- define "app-base.secretName" -}}
{{ include "app-base.fullname" . }}-secrets
{{- end }}

{{/*
ConfigMap name
*/}}
{{- define "app-base.configMapName" -}}
{{ include "app-base.fullname" . }}-config
{{- end }}
