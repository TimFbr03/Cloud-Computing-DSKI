{{- define "calculator.name" -}}
api-calculator
{{- end }}

{{- define "calculator.fullname" -}}
{{ .Release.Name }}-{{ include "calculator.name" . }}
{{- end }}