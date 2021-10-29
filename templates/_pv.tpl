{{/*
All the volumes
*/}}
{{- define "stack.helpers.volumes" -}}
{{-   $Values := .Values -}}
{{-   $volumes := dict -}}
{{-   range $volName, $volValue := .Values.volumes -}}
{{-     $originalName := $volName -}}
{{-     $volName = $volName | replace "_" "-" -}}
{{-     $volValue = default dict $volValue -}}
{{-     $external := get $volValue "external" | default false -}}
{{-     $externalName := get $volValue "name" | default $originalName | replace "_" "-" -}}
{{-     $dynamic := true -}}
{{-     $driver_opts := default dict $volValue.driver_opts -}}
{{-     $type := default "none" $driver_opts.type -}}
{{-     $src := default "" $driver_opts.device -}}
{{-     $server := "" -}}
{{-     $storage := $volValue.storage -}}
{{-     $subPath := $volValue.subPath -}}
{{-     $o := splitList "," (default "" $driver_opts.o) -}}
{{-     if hasPrefix "./" $src -}}
{{-       $src = clean (printf "%s/%s" (default "." $Values.chdir) $src) -}}
{{-       if not (isAbs $src) -}}
{{-         fail "volume path or chdir has to be absolute." -}}
{{-       end -}}
{{-     end -}}
{{-     if eq $type "none" -}}
{{-       $dynamic = not $src -}}
{{-     else if eq $type "nfs" -}}
{{-       range $list := $o -}}
{{-         $pair := splitList "=" $list -}}
{{-         if eq (first $pair) "addr" -}}
{{-           $server = (last $pair) -}}
{{-         end -}}
{{-       end -}}
{{-       $dynamic = or (not $src) (not $server) -}}
{{-     end -}}
{{-     $_ := set $volumes $volName (dict "volumeKind" "Volume" "dynamic" $dynamic "storage" $storage "type" $type "src" $src "dst" "" "server" $server "subPath" $subPath "originalName" $originalName "external" $external "externalName" $externalName) -}}
{{-   end -}}
{{-   range $name, $service := .Values.services -}}
{{-     $deploymentKind := include "stack.helpers.deploymentKind" $service -}}
{{-     $containers := omit $service "containers" | prepend ($service.containers | default list) -}}
{{-     range $container := $containers -}}
{{-       range $volValue := $container.volumes -}}
{{-         $mountOptions := include "stack.helpers.normalizeVolumeMount" $volValue | fromYaml -}}
{{-         $volName := $mountOptions.source | replace "_" "-" -}}
{{-         if not (or (hasPrefix "/" $volName) (hasPrefix "./" $volName)) -}}
{{-           $volume := get $volumes $volName -}}
{{-           $_ := set $volume "deploymentKind" $deploymentKind -}}
{{-         end -}}
{{-       end -}}
{{-     end -}}
{{-   end }}
{{ $volumes | toYaml }}
{{- end -}}


{{- define "stack.pv" -}}
{{- $Values := .Values -}}
{{- $Namespace := .Release.Namespace -}}
apiVersion: v1
kind: PersistentVolume
metadata:
  name: {{ printf "%s-%s" $Namespace .volName | quote }}
spec:
  claimRef:
    namespace: {{ $Namespace }}
    name: {{ .volName | quote }}
  persistentVolumeReclaimPolicy: Delete
  accessModes:
    {{- if eq (get .volValue "type") "nfs" }}
    - ReadWriteMany
    {{- else }}
    - ReadWriteOnce
    {{- end }}
  capacity:
    storage: {{ get .volValue "storage" | default "1Gi" | quote }}
  {{- if and (ne (get .volValue "type") "nfs") (get .volValue "src") }}
  hostPath:
    path: {{ get .volValue "src" | quote }}
  {{- end -}}
  {{- if eq (get .volValue "type") "nfs" }}
  nfs:
    server: {{ get .volValue "server" | quote }}
    path: {{ get .volValue "src" | quote }}
  {{- end -}}
{{- end -}}


{{- define "stack.pvc" -}}
{{-   $volName := .volName -}}
{{-   $volValue := .volValue -}}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ $volName | quote }}
spec:
  accessModes:
    {{- if eq (get $volValue "type") "nfs" }}
    - ReadWriteMany
    {{- else }}
    - ReadWriteOnce
    {{- end }}
  {{- if get $volValue "dynamic" -}}
  {{- if ne (get $volValue "type") "none" }}
  storageClassName: {{ get $volValue "type" | quote }}
  {{- end -}}
  {{- else }}
  storageClassName: "manual"
  {{- end }}
  resources:
    requests:
      storage: {{ get $volValue "storage" | default "1Gi" | quote }}
{{- end -}}