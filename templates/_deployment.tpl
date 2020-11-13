{{/*
Kind of the deployment
*/}}
{{- define "stack.helpers.deploymentKind" -}}
{{-   $kind := "Deployment" -}}
{{-   $mode := . | pluck "deploy" | first | default dict | pluck "mode" | first | default "replicated" -}}
{{-   if eq $mode "global" -}}
{{-      $kind = "DaemonSet" -}}
{{-   end -}}
{{-   if .kind -}}
{{-     $kind = .kind -}}
{{-   end -}}
{{ $kind }}
{{- end -}}

{{/*
Affinities from constraints
Result is a dict { "data": $affinities }
*/}}
{{- define "stack.helpers.affinitiesFromConstraints" -}}
{{-   $affinities := list -}}
{{-   range $constraint := . -}}
{{-     $op := "" -}}
{{-     $pair := list -}}
{{-     $curr := splitList "==" $constraint -}}
{{-     if eq (len $curr) 2 -}}
{{-       $op = "In" -}}
{{-       $pair = $curr -}}
{{-     end -}}
{{-     $curr := splitList "!=" $constraint -}}
{{-     if eq (len $curr) 2 -}}
{{-       $op = "NotIn" -}}
{{-       $pair = $curr -}}
{{-     end -}}
{{-     if and (not (contains "==" $constraint)) (not (contains "!=" $constraint)) (hasPrefix "node.labels" $constraint) -}}
{{-       $op = "Exists" -}}
{{-     end -}}
{{-     if or (eq $op "In") (eq $op "NotIn") -}}
{{-       $first := trim (first $pair) -}}
{{-       $last := trim (last $pair) -}}
{{-       if eq $first "node.role" -}}
{{-         $val := toString (eq $last "manager") -}}
{{-         $affinities = append $affinities (dict "key" "node-role.kubernetes.io/master" "operator" $op "values" (list $val)) -}}
{{-       end -}}
{{-       if eq $first "node.hostname" -}}
{{-         $affinities = append $affinities (dict "key" "kubernetes.io/hostname" "operator" $op "values" (list $last)) -}}
{{-       end -}}
{{-       if hasPrefix "node.labels" $first -}}
{{-         $affinities = append $affinities (dict "key" (replace "node.labels." ""  $first) "operator" $op "values" (list $last)) -}}
{{-       end -}}
{{-     end -}}
{{-     if (eq $op "Exists") -}}
{{-       if hasPrefix "node.labels" $constraint -}}
{{-         $affinities = append $affinities (dict "key" (replace "node.labels." "" $constraint) "operator" $op) -}}
{{-       end -}}
{{-     end -}}
{{-   end -}}
{{ dict "data" $affinities | toYaml }}
{{- end -}}

{{- define "stack.helpers.podSpec" }}
{{-   $name := .name | replace "_" "-" }}
{{-   $service := .service }}
{{-   $containers := .containers }}
{{-   $initContainers := .initContainers }}
{{-   $serviceVolumes := .serviceVolumes }}
{{-   $volumeMounts := .volumeMounts }}
{{-   $affinities := .affinities }}
{{-   $restartPolicy := .restartPolicy }}
{{-   $restartPolicyMap := dict "" "" "none" "Never" "on-failure" "OnFailure" "any" "Always" -}}
spec:
  {{- if $affinities }}
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions: {{ $affinities | toYaml | nindent 16 }}
  {{- end -}}
  {{- if $service.dns }}
  dnsPolicy: "None"
  dnsConfig:
    nameservers: {{ $service.dns | toYaml | nindent 10 }}
  {{- end }}

  containers:
  {{- range $index, $container := $containers }}
  {{- /** Set container.environments */}}
  {{-   $environment := include "stack.helpers.normalizeKV" $container.environment | fromYaml }}
  {{-   $_ := set $container "environment" $environment }}
  {{- /** Set container.volumeMounts */}}
  {{-   $volumeMount := index $volumeMounts $index }}
  {{-   $_ := set $container "volumeMounts" $volumeMount }}
  {{- /** Set container.name */}}
  {{-   $maybeWithContainerIndex := "" }}
  {{-   if gt $index 0 }}
  {{-     $maybeWithContainerIndex = printf "-%d" $index }}
  {{-   end }}
  {{-   $name := $container.container_name | default (printf "%s%s" $name $maybeWithContainerIndex) | replace "_" "-" }}
  {{-   $_ := set $container "name" $name }}
  - {{ include "stack.helpers.containerSpec" $container | nindent 4 | trim }}
  {{- end -}}

  {{- if $initContainers }}
  initContainers:
  {{- range $index, $container := $initContainers }}
  {{- /** Set container.environments */}}
  {{-   $environment := include "stack.helpers.normalizeKV" $container.environment | fromYaml }}
  {{-   $_ := set $container "environment" $environment }}
  {{- /** Set container.volumeMounts. NOT WORKED YET. TODO /}}
  {{-   $volumeMount := index $volumeMounts $index }}
  {{-   $_ := set $container "volumeMounts" $volumeMount */}}
  {{-   $_ := set $container "volumeMounts" nil }}
  {{- /** Set container.name */}}
  {{-   $maybeWithContainerIndex := "" }}
  {{-   if gt $index 0 }}
  {{-     $maybeWithContainerIndex = printf "-%d" $index }}
  {{-   end }}
  {{-   $name := $container.container_name | default (printf "%s-init%s" $name $maybeWithContainerIndex) | replace "_" "-" }}
  {{-   $_ := set $container "name" $name }}
  - {{ include "stack.helpers.containerSpec" $container | nindent 4 | trim }}
  {{- end -}}
  {{- end -}}

  {{- if $serviceVolumes }}
  volumes:
    {{- range $volName, $volValue := $serviceVolumes -}}
    {{- if eq (get $volValue "volumeKind") "Volume" }}
    - name: {{ $volName | quote }}
      {{- if get $volValue "type" | eq "hostPath" }}
      hostPath:
        path: {{ get $volValue "src" | quote }}
      {{- else if get $volValue "type" | eq "emptyDir" }}
      emptyDir: {}
      {{- else }}
      persistentVolumeClaim:
        claimName: {{ get $volValue "externalName" | quote }}
      {{- end -}}
    {{- end -}}
    {{- if eq (get $volValue "volumeKind") "ConfigMap" }}
    - name: {{ $volName | quote }}
      configMap:
        name: {{ get $volValue "externalName" | quote }}
        {{- if get $volValue "mode" }}
        defaultMode: {{ get $volValue "mode" }}
        {{- end -}}
    {{- end -}}
    {{- if eq (get $volValue "volumeKind") "Secret" }}
    - name: {{ $volName | quote }}
      secret:
        secretName: {{ get $volValue "externalName" | quote }}
    {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- if $service.imagePullSecrets }}
  imagePullSecrets:
    - name: {{ $service.imagePullSecrets }}
  {{- end -}}
  {{- if $service.serviceAccountName }}
  serviceAccountName: {{ $service.serviceAccountName }}
  {{- end -}}
  {{- if get $restartPolicyMap (get $restartPolicy "condition") }}
  restartPolicy: {{ get $restartPolicyMap (get $restartPolicy "condition") }}
  {{- end -}}
{{- end -}}


{{- define "stack.deployment" -}}
{{-   $name := .name | replace "_" "-" -}}
{{-   $service := .service -}}
{{-   $Values := .Values -}}
{{-   $kind := include "stack.helpers.deploymentKind" $service -}}
{{-   $replicas := $service | pluck "deploy"| first | default dict | pluck "replicas" | first -}}
{{-   $volumes := include "stack.helpers.volumes" (dict "Values" $Values) | fromYaml -}}
{{-   $configs := include "stack.helpers.configs" (dict "Values" $Values) | fromYaml -}}
{{-   $secrets := include "stack.helpers.secrets" (dict "Values" $Values) | fromYaml -}}
{{-   $serviceVolumes := dict -}}
{{-   $volumeMounts := list -}}
{{-   $volumeClaimTemplates := dict -}}
{{-   $constraints := . | pluck "service" | first | default dict | pluck "deploy" | first | default dict | pluck "placement" | first | default dict | pluck "constraints" | first | default list -}}
{{-   $affinities := include "stack.helpers.affinitiesFromConstraints" $constraints | fromYaml | pluck "data" | first -}}
{{-   $restartPolicy := . | pluck "service" | first | default dict | pluck "deploy" | first | default dict | pluck "restart_policy" | first | default dict -}}
{{-   $containers := omit $service "containers" | prepend ($service.containers | default list) -}}
{{-   $initContainers := $service.initContainers | default list -}}

{{-   range $containerIndex, $container := $containers -}}
{{-     $volumeMount := dict -}}
{{-     $maybeWithContainerIndex := "" -}}
{{-     if gt $containerIndex 0 -}}
{{-       $maybeWithContainerIndex = printf "-%d" $containerIndex -}}
{{-     end -}}
{{-     range $volIndex, $volValue := $container.volumes -}}
{{-       $list := splitList ":" $volValue -}}
{{-       $volName := first $list -}}
{{-       $readOnly := false -}}
{{-       if and (len $list | lt 2) -}}
{{-         if index $list 2 | eq "ro" -}}
{{-           $readOnly = true -}}
{{-         end -}}
{{-       end -}}
{{-       if hasPrefix "/" $volName -}}
{{-         $_ := set $serviceVolumes (printf "volume%s-%d" $maybeWithContainerIndex $volIndex) (dict "volumeKind" "Volume" "type" "hostPath" "src" $volName "dst" (index $list 1) "readOnly" $readOnly) -}}
{{-         $_ := set $volumeMount (printf "volume%s-%d" $maybeWithContainerIndex $volIndex) (dict "volumeKind" "Volume" "type" "hostPath" "src" $volName "dst" (index $list 1) "readOnly" $readOnly) -}}
{{-       else if hasPrefix "./" $volName -}}
{{-         $src := clean (printf "%s/%s" (default "." $Values.chdir) $volName) -}}
{{-         if not (isAbs $src) -}}
{{-           fail "volume path or chidir has to be absolute." -}}
{{-         end -}}
{{-         $_ := set $serviceVolumes (printf "volume%s-%d" $maybeWithContainerIndex $volIndex) (dict "volumeKind" "Volume" "type" "hostPath" "src" $src "dst" (index $list 1) "readOnly" $readOnly) -}}
{{-         $_ := set $volumeMount (printf "volume%s-%d" $maybeWithContainerIndex $volIndex) (dict "volumeKind" "Volume" "type" "hostPath" "src" $src "dst" (index $list 1) "readOnly" $readOnly) -}}
{{-       else -}}
{{-         $volName = $volName | replace "_" "-" -}}
{{-         $curr := get $volumes $volName | deepCopy -}}
{{-         $curr = mergeOverwrite $curr (dict "dst" (index $list 1) "readOnly" $readOnly) -}}
{{-         $_ := set $volumeMount $volName $curr -}}
{{-         if and (eq $kind "StatefulSet") (ne (get $curr "type") "emptyDir") (get $curr "dynamic") -}}
{{-           $_ := set $volumeClaimTemplates $volName $curr -}}
{{-         else -}}
{{-           $_ := set $serviceVolumes $volName $curr -}}
{{-         end -}}
{{-       end -}}
{{-     end -}}
{{-     range $volValue := $container.configs -}}
{{-       if (typeOf $volValue) | ne "string" -}}
{{-         $volName := get $volValue "source" | replace "_" "-" -}}
{{-         $curr := get $configs $volName | deepCopy -}}
{{-         $curr = mergeOverwrite $curr $volValue -}}
{{-         $_ := set $serviceVolumes $volName $curr -}}
{{-         $_ := set $volumeMount $volName $curr -}}
{{-       else -}}
{{-         $volName := $volValue | replace "_" "-" -}}
{{-         $_ := set $serviceVolumes $volName (get $configs $volName) -}}
{{-         $_ := set $volumeMount $volName (get $configs $volName) -}}
{{-       end -}}
{{-     end -}}
{{-     range $volValue := $container.secrets -}}
{{-       if (typeOf $volValue) | ne "string" -}}
{{-         $volName := get $volValue "source" | replace "_" "-" -}}
{{-         $curr := get $secrets $volName | deepCopy -}}
{{-         $curr = mergeOverwrite $curr $volValue -}}
{{-         $_ := set $serviceVolumes $volName $curr -}}
{{-         $_ := set $volumeMount $volName $curr -}}
{{-       else -}}
{{-         $volName := $volValue | replace "_" "-" -}}
{{-         $_ := set $serviceVolumes $volName (get $secrets $volName) -}}
{{-         $_ := set $volumeMount $volName (get $secrets $volName) -}}
{{-       end -}}
{{-     end -}}
{{-     $volumeMounts = append $volumeMounts $volumeMount -}}
{{-   end -}}
{{- $podSpec := include "stack.helpers.podSpec" (dict "name" $name "service" $service "containers" $containers "initContainers" $initContainers "serviceVolumes" $serviceVolumes "volumeMounts" $volumeMounts "affinities" $affinities "restartPolicy" $restartPolicy) | fromYaml -}}
{{- if eq $kind "Job" -}}
apiVersion: batch/v1
kind: {{ $kind }}
metadata:
  name: {{ $name | quote }}
spec:
  template:
    {{ mergeOverwrite (dict "spec" (dict "restartPolicy" "Never")) $podSpec | toYaml | nindent 4 }}
{{- else if eq $kind "CronJob" -}}
apiVersion: batch/v1beta1
kind: {{ $kind }}
metadata:
  name: {{ $name | quote }}
spec:
  schedule: "*/1 * * * *"
  jobTemplate:
    spec:
      template:
        {{ mergeOverwrite (dict "spec" (dict "restartPolicy" "Never")) $podSpec | toYaml | nindent 8 }}
{{- else -}}
apiVersion: apps/v1
kind: {{ $kind }}
metadata:
  name: {{ $name | quote }}
spec:
  {{- if and (ne $kind "DaemonSet") $replicas }}
  replicas: {{ $replicas }}
  {{- end }}
  selector:
    matchLabels:
      service: {{ $name | quote }}
  {{- if eq $kind "StatefulSet" }}
  serviceName: {{ $name | quote }}
  {{- end }}
  template:
    metadata:
      labels:
        service: {{ $name | quote }}
    {{ $podSpec | toYaml | nindent 4 }}
  {{- if $volumeClaimTemplates }}
  volumeClaimTemplates:
    {{- range $volName, $volValue := $volumeClaimTemplates -}}
    {{- $pvc := include "stack.pvc" (dict "volName" $volName "volValue" $volValue) | fromYaml }}
    - metadata: {{ get $pvc "metadata" | toYaml | nindent 8 }}
      spec: {{ get $pvc "spec" | toYaml | nindent 8 }}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}

