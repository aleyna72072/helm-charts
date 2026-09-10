{{- /*
  This is the shared spec template for eduMFA pods.

  It takes a dictionary with the following required keys:
  - Chart: .Chart
  - Values: .Values
  - specSettings: dictionary with optional template provided parameters
  - specValues: dictionary with optional user/values provided parameters
    + keys: resources, env, volumeMounts, volumes, nodeSelector, affinity, tolerations
    + In practice this would be .Values.edumfa.worker, .Values.edumfa.init or similar.
    + Note that podAnnotations are handled in the calling template.
*/}}

{{- define "edumfa.spec" }}
{{- /* Check that if there either a CONTAINER_TYPE or a command set. This avoids running the single-node docker entrypoint. */}}
{{- if not (or (hasKey .specSettings "command") (and (hasKey .specSettings "env") (contains "CONTAINER_TYPE" .specSettings.env))) }}
  {{- required "Chart error: Either CONTAINER_TYPE or a command must be set!" "" }}
{{- end}}
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
securityContext:
  runAsNonRoot: true
  runAsUser: 2000
  runAsGroup: 2000
  fsGroup: 2000
  fsGroupChangePolicy: "Always"
  seccompProfile:
    type: RuntimeDefault
containers:
- name: {{ .Chart.Name }}
  securityContext:
    privileged: false
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL
  {{- /* TODO remove on v1.0.0 */}}
  {{- if or (ne .Values.image.repository "ghcr.io/edumfa/edumfa") .Values.image.tag }}
  image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
  {{- else }}
  image: "ghcr.io/edumfa/edumfa@sha256:c5ae9651a8676a6240d015465491a7d5ee5bd558803187fd0bc571f1f704e50f"
  {{- end }}
  imagePullPolicy: {{ .Values.image.pullPolicy }}
  {{- if hasKey .specSettings "command" }}
  command:
    {{- range .specSettings.command }}
    - {{ . | quote }}
    {{- end }}
  {{- end }}
  {{- with .specValues.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  env:
    {{- if hasKey .specSettings "env" }}
      {{- tpl .specSettings.env . | nindent 4 }}
    {{- end }}
    - name: DB_DRIVER
      value: {{ required "DB_DRIVER is required" .Values.edumfa.db.driver | quote }}
    - name: DB_HOSTNAME
      value: {{ required "DB_HOSTNAME is required" .Values.edumfa.db.hostname | quote }}
    - name: DB_USER
      value: {{ required "DB_USER is required" .Values.edumfa.db.user | quote }}
    - name: DB_DATABASE
      value: {{ required "DB_DATABASE is required" .Values.edumfa.db.database | quote }}
    - name: EDUMFA_ENCFILE
      value: /run/edumfa-essential-secrets/enckey
    - name: EDUMFA_AUDIT_KEY_PRIVATE
      value: /run/edumfa-essential-secrets/private.pem
    - name: EDUMFA_AUDIT_KEY_PUBLIC
      value: /run/edumfa-essential-secrets/public.pem
    - name: SECRET_KEY_FILE
      value: /run/edumfa-essential-secrets/secret_key
    - name: EDUMFA_PEPPER_FILE
      value: /run/edumfa-essential-secrets/pepper
    - name: DB_PASSWORD_FILE
      value: /run/edumfa-db-password
    {{- with .Values.edumfa.env }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with .specValues.env }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
  volumeMounts:
    - mountPath: /tmp
      name: tmp
    - mountPath: /run/edumfa-essential-secrets/
      name: essential-secrets
      readOnly: true
    - mountPath: /run/edumfa-db-password
      subPath: {{ required "If .Values.edumfa.admin.password.existingSecret is set, a key must be given, too!" .Values.edumfa.db.password.key }}
      name: db-password-secret
      readOnly: true
    {{- if hasKey .specSettings "volumeMounts" }}
      {{- tpl .specSettings.volumeMounts . | nindent 4 }}
    {{- end }}
    {{- with .specValues.volumeMounts }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- if hasKey .specSettings "containerExtraConf" }}
    {{- tpl .specSettings.containerExtraConf . | nindent 2 }}
  {{- end}}
volumes:
  - name: tmp
    emptyDir: {}
  - name: essential-secrets
    secret:
      secretName: {{ required "A secret containing the essential eduMFA secrets has to be provided." .Values.edumfa.essentialSecretName }}
      # This makes sure essential-secrets contains all necessary fields.
      items:
        - key: enckey
          path: enckey
        - key: pepper
          path: pepper
        - key: private.pem
          path: private.pem
        - key: public.pem
          path: public.pem
        - key: secret_key
          path: secret_key
      defaultMode: 0440
  - name: db-password-secret
    secret:
      secretName: {{ required "A secret containing the database password has to be provided." .Values.edumfa.db.password.existingSecret }}
      items:
        - key: {{ required "A key for the database password secret has to be provided." .Values.edumfa.db.password.key }}
          path: {{ required "A key for the database password secret has to be provided." .Values.edumfa.db.password.key }}
      defaultMode: 0440
  {{- if hasKey .specSettings "volumes" }}
    {{- tpl .specSettings.volumes . | nindent 2 }}
  {{- end }}
  {{- with .specValues.volumes }}
    {{- toYaml . | nindent 2 }}
  {{- end }}

{{- with .specValues.nodeSelector }}
nodeSelector:
{{- toYaml . | nindent 2 }}
{{- end }}

{{- with .specValues.affinity }}
affinity:
{{- toYaml . | nindent 2 }}
{{- end }}

{{- with .specValues.tolerations }}
tolerations:
{{- toYaml . | nindent 2 }}
{{- end }}

{{- end }}
