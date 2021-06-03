{{/* vim: set filetype=mustache: */}}

{{/* Expand the name of the chart.  */}}
{{- define "bms.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
  Create a default fully qualified app name.
  We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
  If release name contains chart name it will be used as a full name.
*/}}
{{- define "bms.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Create chart name and version as used by the chart label.  */}}
{{- define "bms.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Common labels */}}
{{- define "bms.labels" -}}
app.kubernetes.io/name: {{ include "bms.name" . }}
helm.sh/chart: {{ include "bms.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end -}}

{{- define "bms.emailurl" -}}
http://{{ include "bms.name" .}}:9292/report/email
{{- end -}}

{{- define "bms.production.yml" -}}
{{ .File.Get "config/production.yml" }}
{{- end -}}

{{/* Create the cron schedule string */}}
{{/* SPACING IS VERY IMPORTANT */}}
{{- define "bms.cronstring" -}}
{{ .minute | default "0" }} {{ .hour | default "12" }} {{ .daysofmonth | default "*" }} {{ .month | default "*" }} {{ .daysofweek | default "*" }}
{{- end -}}
