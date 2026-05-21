{{- define "backstage.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "backstage.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
backstage.io/kubernetes-id: {{ .Chart.Name }}
{{- end }}

{{- define "backstage.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "backstage.image" -}}
{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}
{{- end }}

{{- define "backstage.kubernetesReaderName" -}}
{{ include "backstage.fullname" . }}-kubernetes-read
{{- end }}

{{- define "backstage.githubSecretName" -}}
{{- if .Values.github.auth.create }}
{{- include "backstage.fullname" . }}-github
{{- else }}
{{- required "github.auth.existingSecret is required when github.auth.create=false" .Values.github.auth.existingSecret }}
{{- end }}
{{- end }}

{{- define "backstage.githubOAuthSecretName" -}}
{{- if .Values.oauth.github.create }}
{{- include "backstage.fullname" . }}-github-oauth
{{- else }}
{{- required "oauth.github.existingSecret is required when oauth.github.create=false" .Values.oauth.github.existingSecret }}
{{- end }}
{{- end }}

{{- define "backstage.postgresSecretName" -}}
{{- if and .Values.postgres.enabled .Values.postgres.auth.create }}
{{- include "backstage.fullname" . }}-postgres
{{- else }}
{{- .Values.postgres.auth.existingSecret }}
{{- end }}
{{- end }}
