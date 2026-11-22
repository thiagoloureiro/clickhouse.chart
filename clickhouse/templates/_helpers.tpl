{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "clickhouse.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "clickhouse.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "clickhouse.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create clickhouse path. 
if .Values.clickhouse.path is empty, default value "/var/lib/clickhouse".
*/}}
{{- define "clickhouse.fullpath" -}}
{{- if .Values.clickhouse.path -}}
{{- .Values.clickhouse.path | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s" "/var/lib/clickhouse" -}}
{{- end -}}
{{- end -}}

{{/*
Create clickhouse log path.
if .Values.clickhouse.configmap.logger.path is empty, default value "/var/log/clickhouse-server".
*/}}
{{- define "clickhouse.logpath" -}}
{{- if .Values.clickhouse.configmap.logger.path -}}
{{- .Values.clickhouse.configmap.logger.path | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s" "/var/log/clickhouse-server" -}}
{{- end -}}
{{- end -}}

{{/*
ClickHouse server image reference.
When dhi.enabled is true, uses Docker Hardened Images from dhi.io.
*/}}
{{- define "clickhouse.image" -}}
{{- if .Values.clickhouse.dhi.enabled -}}
{{- printf "%s:%s" .Values.clickhouse.dhi.image .Values.clickhouse.dhi.imageVersion -}}
{{- else -}}
{{- printf "%s:%s" .Values.clickhouse.image (.Values.clickhouse.imageVersion | default .Chart.AppVersion) -}}
{{- end -}}
{{- end -}}

{{/*
ClickHouse Keeper image reference.
Follows DHI settings when enabled; otherwise uses keeper-specific image values.
*/}}
{{- define "clickhouse.keeper.image" -}}
{{- if .Values.clickhouse.dhi.enabled -}}
{{- printf "%s:%s" .Values.clickhouse.dhi.image .Values.clickhouse.dhi.imageVersion -}}
{{- else -}}
{{- printf "%s:%s" .Values.clickhouse.configmap.keeper.image (.Values.clickhouse.configmap.keeper.imageVersion | default .Chart.AppVersion) -}}
{{- end -}}
{{- end -}}

{{/*
Validate DHI configuration and render imagePullSecrets.
dhi.io requires authentication, so imagePullSecrets must be set when DHI is enabled.
*/}}
{{- define "clickhouse.imagePullSecrets" -}}
{{- if and .Values.clickhouse.dhi.enabled (not .Values.clickhouse.imagePullSecrets) -}}
{{- fail "clickhouse.imagePullSecrets is required when clickhouse.dhi.enabled is true (dhi.io requires registry authentication)" -}}
{{- end -}}
{{- if .Values.clickhouse.imagePullSecrets }}
      imagePullSecrets:
    {{- range .Values.clickhouse.imagePullSecrets }}
      - name: {{ . | quote }}
    {{- end }}
{{- end }}
{{- end -}}

{{/*
Pod securityContext for ClickHouse pods.
DHI images run as uid/gid 1001; when DHI is enabled and no podSecurityContext is set,
default to that user so PVC ownership matches.
*/}}
{{- define "clickhouse.podSecurityContext" }}
{{- if .Values.clickhouse.podSecurityContext }}
      securityContext:
        {{- toYaml .Values.clickhouse.podSecurityContext | nindent 8 }}
{{- else if .Values.clickhouse.dhi.enabled }}
      securityContext:
        runAsUser: 1001
        runAsGroup: 1001
        fsGroup: 1001
{{- end }}
{{- end }}

{{/*
Pod securityContext for Keeper pods.
*/}}
{{- define "clickhouse.keeper.podSecurityContext" }}
{{- if .Values.clickhouse.configmap.keeper.podSecurityContext }}
      securityContext:
        {{- toYaml .Values.clickhouse.configmap.keeper.podSecurityContext | nindent 8 }}
{{- else if .Values.clickhouse.dhi.enabled }}
      securityContext:
        runAsUser: 1001
        runAsGroup: 1001
        fsGroup: 1001
{{- end }}
{{- end }}
