{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "stack.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "stack.fullname" -}}
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
{{- define "stack.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "stack.labels" -}}
helm.sh/chart: {{ include "stack.chart" . }}
{{ include "stack.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "stack.selectorLabels" -}}
app.kubernetes.io/name: {{ include "stack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "stack.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "stack.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Normalize k:v or k=v style. Useful for volumes and labels
*/}}
{{- define "stack.helpers.normalizeKV" -}}
{{-   $dict := dict -}}
{{-   $isList := eq (typeOf .) "[]interface {}" -}}
{{-   range $name, $value := . -}}
{{-     if $isList -}}
{{-       $list := splitList "=" $value -}}
{{-       $name = first $list -}}
{{-       $value = join "=" (rest $list) -}}
{{-     end -}}
{{-     $_ := set $dict $name $value -}}
{{-   end -}}
{{ $dict | toYaml }}
{{- end -}}


{{/*
Normalize entrypoint
*/}}
{{- define "stack.helpers.normalizeEntrypoint" -}}
{{-   $entrypoint := . -}}
{{-   if $entrypoint -}}
{{-     $isList := eq (typeOf $entrypoint) "[]interface {}" -}}
{{-     if not $isList -}}
{{-       $list := splitList " " $entrypoint -}}
{{-       if eq (len $list) 1 -}}
{{-         $entrypoint = $list -}}
{{-       else -}}
{{-         $entrypoint = list "/bin/sh" "-c" $entrypoint -}}
{{-       end -}}
{{-     end -}}
{{-   end -}}
{{ $entrypoint | toYaml }}
{{- end -}}


{{/*
Normalize command
*/}}
{{- define "stack.helpers.normalizeCommand" -}}
{{-   $command := . -}}
{{-   if $command -}}
{{-     $isList := eq (typeOf $command) "[]interface {}" -}}
{{-     if not $isList -}}
{{-       $command = list $command -}}
{{-     end -}}
{{-   end -}}
{{ $command | toYaml }}
{{- end -}}


{{/*
Normalize healthcheck test command
*/}}
{{- define "stack.helpers.normalizeHealthCheckCommand" -}}
{{-   $command := . -}}
{{-   if $command -}}
{{-     $isList := eq (typeOf $command) "[]interface {}" -}}
{{-     if not $isList -}}
{{-       $command = list "/bin/sh" "-c" $command -}}
{{-     else if index $command 0 | eq "CMD-SHELL" -}}
{{-       $command = list "/bin/sh" "-c" (index $command 1) -}}
{{-     else if index $command 0 | eq "CMD" -}}
{{-       $command = slice $command 1 -}}
{{-     else -}}
{{-       $command = list -}}
{{-     end -}}
{{-   end -}}
{{ $command | toYaml }}
{{- end -}}


{{/*
Normalize duration: 3h4m5s7ms8us
*/}}
{{- define "stack.helpers.normalizeDuration" -}}
{{-   $values := regexFindAll "[0-9]+" . -1 -}}
{{-   $units := regexFindAll "(h|m|s|ms|us)" . -1 -}}
{{-   $bases := dict "h" 3600 "m" 60 "s" 1 "ms" 0 "us" 0 -}}
{{-   $duration := 0 -}}
{{-   range $index, $val := $values -}}
{{-     $unit := index $units $index -}}
{{-     $duration = $val | int64 | mul (get $bases $unit | default 0) | add $duration -}}
{{-   end -}}
{{ $duration }}
{{- end -}}


{{/*
Normalize ports:
- port:target/UDP
- port:target
- port
*/}}
{{- define "stack.helpers.normalizePorts" -}}
{{-   $tcp := list -}}
{{-   $udp := list -}}
{{-   range . -}}
{{-     $list := splitList ":" . -}}
{{-     $port := first $list -}}
{{-     $targetPort := last $list -}}
{{-     $protocol := "TCP" -}}
{{-     $maybeTargetWithProto := splitList "/" $targetPort -}}
{{-     if eq (len $maybeTargetWithProto) 2 -}}
{{-       $targetPort = first $maybeTargetWithProto -}}
{{-       $protocol = last $maybeTargetWithProto | upper -}}
{{-     end -}}
{{-     $maybePortRange := splitList "-" $port -}}
{{-     if eq (len $maybePortRange) 2 -}}
{{-       $portStart := first $maybePortRange | int64 -}}
{{-       $portEnd := last $maybePortRange | int64 -}}
{{-       $targetPortStart := splitList "-" $targetPort | first | int64 -}}
{{-       $diff := sub $targetPortStart $portStart -}}
{{-       range $index := until (sub (add1 $portEnd) $portStart | int) -}}
{{-         if eq $protocol "TCP" -}}
{{-           $tcp = append $tcp (dict "protocol" $protocol "port" (add $portStart $index | toString) "targetPort" (add $portStart $diff $index | toString)) -}}
{{-         else -}}
{{-           $udp = append $udp (dict "protocol" $protocol "port" (add $portStart $index | toString) "targetPort" (add $portStart $diff $index | toString)) -}}
{{-         end -}}
{{-       end -}}
{{-     else -}}
{{-       if eq $protocol "TCP" -}}
{{-         $tcp = append $tcp (dict "protocol" $protocol "port" $port "targetPort" $targetPort) -}}
{{-       else -}}
{{-         $udp = append $udp (dict "protocol" $protocol "port" $port "targetPort" $targetPort) -}}
{{-       end -}}
{{-     end -}}
{{-   end -}}
{{ dict "tcp" $tcp "udp" $udp "all" (concat $tcp $udp | default list) | toYaml }}
{{- end -}}


{{/*
Merge Deep Overwrite with nil, dict, list & primitive support
Result is a dict { "data": $mergedData }
*/}}
{{- define "stack.helpers.mergeDeepOverwrite" -}}
{{-   $dst := index . 0 -}}
{{-   $src := index . 1 -}}
{{-   $newDst := "" -}}
{{-   if or (kindIs "invalid" $src) (kindIs "invalid" $dst) -}}
{{-     $newDst = mergeOverwrite (dict "data" $dst) (dict "data" $src) | pluck "data" | first -}}
{{-   else -}}
{{-     $isList := eq (typeOf $dst) "[]interface {}"  -}}
{{-     $isDict := eq (typeOf $dst) "map[string]interface {}"  -}}
{{-     if $isList -}}
{{-       $newDst = list -}}
{{-       range $index := max (len $src) (len $dst) | int | until -}}
{{-         if and (len $src | lt $index) (len $dst | lt $index) -}}
{{-           $srcValue := index $src $index -}}
{{-           $dstValue := index $dst $index -}}
{{-           $newDst = append $newDst (include "stack.helpers.mergeDeepOverwrite" (list $dstValue $srcValue) | fromYaml | pluck "data" | first) -}}
{{-         else if (len $src | lt $index) -}}
{{-           $srcValue := index $src $index -}}
{{-           $newDst = append $newDst $srcValue -}}
{{-         else if (len $dst | lt $index) -}}
{{-           $dstValue := index $dst $index -}}
{{-           $newDst = append $newDst $dstValue -}}
{{-         end -}}
{{-       end -}}
{{-     else if $isDict -}}
{{-       $newDst = dict -}}
{{-       range $key := concat (keys $src) (keys $dst) | uniq -}}
{{-         if and (hasKey $src $key) (hasKey $dst $key) -}}
{{-           $srcValue := get $src $key -}}
{{-           $dstValue := get $dst $key -}}
{{-           $_ := set $newDst $key (include "stack.helpers.mergeDeepOverwrite" (list $dstValue $srcValue) | fromYaml | pluck "data" | first) -}}
{{-         else if (hasKey $src $key) -}}
{{-           $srcValue := get $src $key -}}
{{-           $_ := set $newDst $key $srcValue -}}
{{-         else if (hasKey $dst $key) -}}
{{-           $dstValue := get $dst $key -}}
{{-           $_ := set $newDst $key $dstValue -}}
{{-         end -}}
{{-       end -}}
{{-     else -}}
{{-       $newDst = mergeOverwrite (dict "data" $dst) (dict "data" $src) | pluck "data" | first -}}
{{-     end -}}
{{-   end -}}
{{ dict "data" $newDst | toYaml }}
{{- end -}}