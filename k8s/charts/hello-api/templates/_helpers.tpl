{{/* Common labels on every resource. */}}
{{- define "hello-api.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end }}

{{/* Selector labels for one component (app, postgres, redis). */}}
{{- define "hello-api.selector" -}}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{- define "hello-api.dbHost" -}}
{{- if .Values.postgres.enabled }}{{ .Release.Name }}-postgres{{ else }}{{ required "externalDatabaseHost is required when postgres.enabled=false" .Values.externalDatabaseHost }}{{ end }}
{{- end }}
