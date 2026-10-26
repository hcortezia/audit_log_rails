## [Unreleased]

## [0.2.0]

- `masked_attributes` (global e por model) e `mask_value`: a alteracao de campo sensivel (senha, token) e registrada sem os valores. Antes, ignorar o campo fazia a troca de senha sumir do historico.
- Falha ao gravar o log nao derruba mais a requisicao (o log roda depois do commit): vira log de erro e chama `error_handler`. `raise_errors = true` faz o erro subir (util em teste).
- Registro "dono": colunas `owner_type`/`owner_id`, `auditable owner: :associacao` (ou Proc) e o scope `AuditLog.of_owner(registro)`, para o historico de um agregado (ex.: pessoa + contratos). Sem `owner`, o dono e o proprio registro.
- `resolve_associations`: em belongs_to, o payload humanizado traz `old_value_label`/`new_value_label` com o rotulo do registro associado (inclui registros com soft delete).
- `AuditLogger.record_event`: eventos que nao passam pelos callbacks (reset de senha, login, `update_all`).
- Generator `audit_logger:upgrade` para quem ja tem a tabela da 0.1.x.
- Dependencias de desenvolvimento atualizadas para corrigir CVEs (nokogiri, sqlite3, json, erb, loofah, crass, rails-html-sanitizer, concurrent-ruby).

## [0.1.1] - 2026-05-22

- Add `lib/audit_log_rails.rb` so the published gem autoloads correctly when installed as `audit_log_rails`

## [0.1.0] - 2026-05-19

- Initial release
