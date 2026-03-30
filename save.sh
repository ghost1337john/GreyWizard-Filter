      # Ajout de l'option dns.rewrites.enabled: true
      if command -v yq >/dev/null 2>&1; then
        yq -i '.dns.rewrites.enabled = true' "$yaml_path"
      else
        # Ajout manuel si la section dns: existe déjà
        if grep -q '^dns:' "$yaml_path"; then
          sed -i '/^dns:/a\  rewrites:\n    enabled: true' "$yaml_path"
        else
          # Ajoute la section complète à la fin
          echo -e '\ndns:\n  rewrites:\n    enabled: true' >> "$yaml_path"
        fi
      fi

    # Injection du bloc rewrites généré dans AdGuardHome.yaml
    REWRITES_YAML="config/adguardhome/conf/rewrites.yaml"
    if [ -f "$REWRITES_YAML" ]; then
      log_info "Injection des entrées rewrites dans AdGuardHome.yaml..."
      if command -v yq >/dev/null 2>&1; then
        # Supprime la section rewrites existante
        yq -i 'del(.rewrites)' "$yaml_path"
        # Ajoute les nouvelles entrées rewrites
        yq -i '(. + load("'"$REWRITES_YAML"'"))' "$yaml_path"
        log_success "Bloc rewrites injecté via yq."
      else
        # Méthode manuelle : supprime l'ancien bloc rewrites et ajoute le nouveau à la fin
        sed -i '/^rewrites:/,/^\s*[^- ]/d' "$yaml_path"
        cat "$REWRITES_YAML" >> "$yaml_path"
        log_success "Bloc rewrites injecté manuellement."
      fi
    fi