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
{{-     $constraint := . -}}
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
key: node-role.kubernetes.io/master
operator: {{ $op }}
values: [{{ $val }}]
{{-       end -}}
{{-       if eq $first "node.hostname" -}}
key: kubernetes.io/hostname
operator: {{ $op }}
values: [{{ $last }}]
{{-       end -}}
{{-       if hasPrefix "node.labels" $first -}}
key: {{ replace "node.labels." ""  $first }}
operator: {{ $op }}
values: [{{ $last }}]
{{-       end -}}
{{-     end -}}
{{-     if (eq $op "Exists") -}}
{{-       if hasPrefix "node.labels" $constraint -}}
key: {{ replace "node.labels." "" $constraint }}
operator: {{ $op }}
{{-       end -}}
{{-     end -}}
{{- end -}}

{{- define "stack.helpers.tolerations" }}
{{-   if not (eq (typeOf .) "string") }}
{{-     fail "deploy.placement.tolerations[*] must be string" }}
{{-   end }}
{{-   if not (regexMatch "^[^=:]+(=[^=:]+)?(:(NoSchedule|PreferNoSchedule|NoExecute))?$" .) }}
{{-     fail "deploy.placement.tolerations[] must be 'key[=value][:(NoSchedule|PreferNoSchedule|NoExecute)]'"}}
{{-   end }}
{{-   $tokens := splitList ":" . }}
{{-   if eq (len $tokens) 2 }}
effect: {{ index $tokens 1 }}
{{-   end }}
{{-   $pair := index $tokens 0 | splitList "=" }}
key: {{ index $pair 0 }}
{{-   if eq (len $pair) 1 }}
operator: Exists
{{-   else }}
operator: Equal
value: {{ index $pair 1 }}
{{-   end }}
{{- end }}

{{- define "stack.helpers.podSpec" }}
{{-   $name := .name | replace "_" "-" }}
{{-   $owner_kind := .owner_kind }}
{{-   $service := .service }}
{{-   $configs := .configs }}
{{-   $secrets := .secrets }}
{{-   $volumes := .volumes }}
{{-   $containers := .containers }}
{{-   $initContainers := .initContainers }}
{{-   $placement := .placement }}
{{-   $restartPolicy := .restartPolicy }}
{{-   $restartPolicyMap := dict "" "" "none" "Never" "on-failure" "OnFailure" "any" "Always" -}}
{{- /* Variables */ -}}
{{-   $podVolumes := dict -}}
{{-   $context := dict "owner_kind" $owner_kind "configs" $configs "secrets" $secrets "volumes" $volumes "podVolumes" $podVolumes }}
spec:
  {{- $affinities := $placement.constraints }}
  {{- if $affinities }}
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
            {{- range $expression := $affinities }}
            - {{ include "stack.helpers.affinitiesFromConstraints" $expression | indent 14 | trim }}
            {{- end }}
  {{- end }}

  {{- $tolerations := $placement.tolerations }}
  {{- if $tolerations }}
  tolerations:
  {{- range $toleration := $service.deploy.placement.tolerations }}
  - {{ include "stack.helpers.tolerations" $toleration | indent 4 | trim }}
  {{- end }}
  {{- end }}

  {{- if $service.dns }}
  dnsPolicy: "None"
  dnsConfig:
    nameservers: {{ $service.dns | toYaml | nindent 10 }}
  {{- end }}

  containers:
  {{- $params := dict "service" $service "containers" $containers "initContainers" $initContainers "name" $name }}
  {{ include "stack.helpers.containerList" (merge dict $context $params) }}

  {{- if $initContainers }}
  initContainers:
  {{- $params := dict "service" $service "containers" (deepCopy $initContainers) "name" (printf "%s-init" $name) }}
  {{ include "stack.helpers.containerList" (merge dict $context $params) }}
  {{- end }}

  {{- if eq "host" ($containers | first | pluck "network_mode" | first | default "default") }}
  hostNetwork: true
  {{- end }}

  {{- if $podVolumes }}
  volumes:
  {{- range $volValue := $podVolumes }}
  {{-   $volName := $volValue.name }}
    - name: {{ $volName | quote }}
    {{- if eq $volValue.volumeKind "Volume" }}
      {{- if eq $volValue.type "hostPath" }}
      hostPath:
        path: {{ $volValue.src | default $volValue.source | quote }}
      {{- else if eq $volValue.type "emptyDir" }}
      emptyDir: {}
      {{- else }}
      persistentVolumeClaim:
        claimName: {{ $volValue.externalName | quote }}
      {{- end }}
    {{- end }}
    {{- if eq $volValue.volumeKind "ConfigMap" }}
      configMap:
        name: {{ $volValue.externalName | quote }}
        {{- if $volValue.mode }}
        defaultMode: {{ $volValue.mode }}
        {{- end }}
    {{- end }}
    {{- if eq $volValue.volumeKind "Secret" }}
      secret:
        secretName: {{ $volValue.externalName | quote }}
        {{- if $volValue.mode }}
        defaultMode: {{ $volValue.mode }}
        {{- end }}
    {{- end }}
  {{- end }}
  {{- end }}

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
{{-   $kind := .kind -}}
{{-   $service := .service -}}
{{-   $replicas := $service | pluck "deploy"| first | default dict | pluck "replicas" | first -}}
{{-   $volumes := include "stack.helpers.volumes" (dict "Values" .Values) | fromYaml -}}
{{-   $configs := include "stack.helpers.configs" (dict "Values" .Values) | fromYaml -}}
{{-   $secrets := include "stack.helpers.secrets" (dict "Values" .Values) | fromYaml -}}
{{-   $volumeClaimTemplates := dict -}}
{{-   $placement := include "getPath" (list $service "deploy.placement") | fromYaml | default dict -}}
{{-   $restartPolicy := . | pluck "service" | first | default dict | pluck "deploy" | first | default dict | pluck "restart_policy" | first | default dict -}}
{{-   $containers := omit $service "containers" | prepend ($service.containers | default list) -}}
{{-   $initContainers := $service.initContainers | default list -}}

{{-   range $container := (concat $containers $initContainers) -}}
{{-     range $mount := $container.volumes -}}
{{-       $mountOptions := include "stack.helpers.volumeMountOptions" $mount | fromYaml -}}
{{-       $volName := $mountOptions.source | replace "_" "-" -}}
{{-       if not (or (hasPrefix "/" $volName) (hasPrefix "./" $volName)) -}}
{{- /* TODO: Check `volumes.XXX` existences and validity */ -}}
{{-         $curr := get $volumes $volName | deepCopy -}}
{{-         if and (eq $kind "StatefulSet") (ne $curr.type "emptyDir") (not $curr.external) (get $curr "dynamic") -}}
{{-           $_ := set $volumeClaimTemplates $volName $curr -}}
{{-         end -}}
{{-       end -}}
{{-     end -}}
{{-   end -}}
{{- $podSpec := include "stack.helpers.podSpec" (dict "name" $name "owner_kind" $kind "service" $service "volumes" $volumes "configs" $configs "secrets" $secrets "containers" $containers "initContainers" $initContainers "placement" $placement "restartPolicy" $restartPolicy) | fromYaml -}}

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

