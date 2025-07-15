{{- define "myapi.name" -}}
myapi
{{- end }}

{{- define "myapi.fullname" -}}
{{ include "myapi.name" . }}
{{- end }}