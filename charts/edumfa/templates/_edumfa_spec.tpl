{{- define "edumfa.spec" }}
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
  {{/* TODO remove on v1.0.0 */}}
  {{- if or (ne .Values.image.repository "ghcr.io/edumfa/edumfa") .Values.image.tag }}
  image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
  {{- else }}
  image: "ghcr.io/edumfa/edumfa@sha256:c5ae9651a8676a6240d015465491a7d5ee5bd558803187fd0bc571f1f704e50f"
  {{- end }}
  imagePullPolicy: {{ .Values.image.pullPolicy }}
  {{- with .command }}
  command:
    {{- range . }}
    - {{ . | quote }}
    {{- end }}
  {{- end }}
  {{- if eq .containerType "helm_worker" }}
  ports:
  - name: http
    containerPort: 8000
    protocol: TCP
  {{- with .Values.edumfa.worker.livenessProbe }}
  livenessProbe:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.edumfa.worker.readinessProbe }}
  readinessProbe:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- end }}
  {{- with .specSettings.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  env:
  {{- if eq .containerType "helm_init" }}
  - name: CONTAINER_TYPE
    value: "helm_init"
    {{- if .Values.edumfa.admin.enabled }}
  - name: EDUMFA_ADMIN_ENABLE
    value: "true"
      {{- with .Values.edumfa.admin.username }}
  - name: EDUMFA_ADMIN_USER
    value: {{ . }}
      {{- end }}
      {{- if .Values.edumfa.admin.password.existingSecret }}
  - name: EDUMFA_ADMIN_PASS_FILE
    value: /run/edumfa-admin-password
      {{- end }}
    {{- else }}
  - name: EDUMFA_ADMIN_ENABLE
    value: "false"
    {{- end }}
  {{- else if eq .containerType "helm_worker" }}
  - name: CONTAINER_TYPE
    value: "helm_worker"
  {{- else if eq .containerType "cronjob" }}
    {{- if not .command }}
      {{- required "Cronjobs have to set a command to avoid running the entrypoint!" "" }}
    {{- else }}
  - name: CONTAINER_TYPE
    value: "helm_cronjob"
    {{- end }}
  {{- else }}
  {{- required "Invalid containerType." "" }}
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
    {{- toYaml . | nindent 2 }}
  {{- end }}
  {{- with .specSettings.env }}
    {{- toYaml . | nindent 2 }}
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
    {{- if and (eq .containerType "helm_init") .Values.edumfa.admin.password.existingSecret }}
    - mountPath: /run/edumfa-admin-password
      subPath: {{ required "If .Values.edumfa.admin.password.existingSecret is set, a key must be given, too!" .Values.edumfa.admin.password.key }}
      name: admin-password-secret
      readOnly: true
    {{- end }}
    {{- with .specSettings.volumeMounts }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
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
  {{- if and (eq .containerType "helm_init") .Values.edumfa.admin.password.existingSecret }}
  - name: admin-password-secret
    secret:
      secretName: {{ .Values.edumfa.admin.password.existingSecret }}
      items:
        - key: {{ required "If .Values.edumfa.admin.password.existingSecret is set, a key must be given, too!" .Values.edumfa.admin.password.key }}
          path: {{ required "If .Values.edumfa.admin.password.existingSecret is set, a key must be given, too!" .Values.edumfa.admin.password.key }}
      defaultMode: 0440
  {{- end }}
  {{- with .specSettings.volumes }}
    {{- toYaml . | nindent 2 }}
  {{- end }}

{{- with .specSettings.nodeSelector }}
nodeSelector:
{{- toYaml . | nindent 2 }}
{{- end }}

{{- with .specSettings.affinity }}
affinity:
{{- toYaml . | nindent 2 }}
{{- end }}

{{- with .specSettings.tolerations }}
tolerations:
{{- toYaml . | nindent 2 }}
{{- end }}

{{- end }}
