{{/*
Nome base do release
*/}}
{{- define "minio-provisioner.name" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
