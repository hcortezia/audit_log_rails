# audit_log_rails

[![Gem Version](https://badge.fury.io/rb/audit_log_rails.svg)](https://rubygems.org/gems/audit_log_rails)

Auditoria de models ActiveRecord para Rails: registra quem criou, alterou ou excluiu cada registro, quando e o que mudou (valor antigo e valor novo), numa tabela própria, com uma versão já traduzida para exibir na tela.

```ruby
class Contrato < ApplicationRecord
  auditable owner: :pessoa
end

contrato.update!(cargo: assessor)
contrato.audit_logs.last.audited_changes_humanize
# => { "type" => "update",
#      "fields" => { "cargo_id" => { "label" => "Cargo", "old_value" => 3, "new_value" => 7,
#                                    "old_value_label" => "PROFESSOR", "new_value_label" => "ASSESSOR" } } }
```

## Sumário

- [Recursos](#recursos)
- [Compatibilidade](#compatibilidade)
- [Instalação](#instalação)
- [Configuração](#configuração)
- [Quem fez a alteração (contexto do ator)](#quem-fez-a-alteração-contexto-do-ator)
- [Auditando uma model](#auditando-uma-model)
- [Consultando os logs](#consultando-os-logs)
- [Campos sensíveis](#campos-sensíveis)
- [Histórico de um agregado (dono)](#histórico-de-um-agregado-dono)
- [Rótulo de associações](#rótulo-de-associações)
- [Eventos manuais](#eventos-manuais)
- [Falhas não derrubam a requisição](#falhas-não-derrubam-a-requisição)
- [Formato dos dados](#formato-dos-dados)
- [Tradução dos campos (I18n)](#tradução-dos-campos-i18n)
- [Atualizando da 0.1.x](#atualizando-da-01x)
- [Limitações e cuidados](#limitações-e-cuidados)
- [Desenvolvimento](#desenvolvimento)

## Recursos

- **`auditable` na model:** registra `create`, `update` e `destroy` depois do commit. Se houver rollback, nada é gravado.
- **Só o que mudou:** em `update`, guarda apenas os campos alterados, com `old_value` e `new_value`.
- **Dois formatos:** o bruto (`audited_changes`) e o humanizado (`audited_changes_humanize`), com o nome traduzido de cada campo.
- **Campos sensíveis mascarados:** a troca de senha ou token fica registrada, sem os valores.
- **Rótulo de associações:** em `belongs_to`, o humanizado traz o nome do registro ("PROFESSOR → ASSESSOR"), e não só o id.
- **Dono do registro:** junta num só histórico a pessoa, os contratos e os dependentes dela.
- **Eventos manuais:** para o que não passa por callback, como login, pedido de reset de senha e `update_all`.
- **Falha segura:** se gravar o log falhar, a requisição do usuário não quebra.
- **Contexto do ator:** usuário, tipo, metadados, IP e um uuid que agrupa as alterações da mesma requisição.

## Compatibilidade

| | Versão |
|---|---|
| Ruby | `>= 3.1` |
| Rails / ActiveRecord | `>= 7.0` e `< 9.0` |
| Banco | PostgreSQL (a migration usa `jsonb`). Em outros bancos, troque as colunas JSON por `text`: a gem serializa sozinha. |

A gem se chama `audit_log_rails`, mas o namespace Ruby é `AuditLogger`.

## Instalação

1. Adicione a gem ao `Gemfile` e instale:

   ```ruby
   gem "audit_log_rails"
   ```

   ```bash
   bundle install
   ```

2. Gere a migration e o initializer:

   ```bash
   bin/rails generate audit_logger:install
   ```

   O comando cria:
   - `db/migrate/<timestamp>_create_audit_logs.rb`: a tabela `audit_logs`;
   - `config/initializers/audit_logger.rb`: a configuração, com os exemplos comentados.

3. Rode a migration:

   ```bash
   bin/rails db:migrate
   ```

4. Ajuste o initializer para o seu app: quem é o usuário atual, o IP e assim por diante. Veja [Configuração](#configuração).

5. Coloque `auditable` nas models que quiser auditar.

### A tabela `audit_logs`

| Coluna | Conteúdo |
|---|---|
| `model_class_name` | Classe auditada, ex.: `Contrato` |
| `id_object` | Id do registro auditado (texto) |
| `action` | `create`, `update`, `destroy` ou o nome do evento manual |
| `uuid` | Agrupa os logs da mesma requisição ou fluxo |
| `changed_by_id` / `changed_by_type` | Quem fez a alteração |
| `changed_by_other` | JSON livre com metadados do ator (nome, e-mail, request id...) |
| `audited_changes` | Payload bruto |
| `audited_changes_humanize` | Payload humanizado |
| `ip_remote` | IP de origem |
| `owner_type` / `owner_id` | Registro "dono" do log (desde a 0.2.0) |
| `created_at`, `updated_at`, `deleted_at` | Datas |

A migration também cria os índices de consulta: por model e id, uuid, ação, ator, dono e data.

## Configuração

Tudo fica em `config/initializers/audit_logger.rb`:

```ruby
AuditLogger.configure do |config|
  # Quem fez a alteração.
  config.changed_by_id_resolver = -> { Current.user&.id }
  config.changed_by_type_resolver = -> { Current.user&.class&.name }
  config.changed_by_other_resolver = -> { { nome: Current.user&.nome, request_id: Current.request_id }.compact }

  # Agrupamento e origem.
  config.uuid_resolver = -> { Current.request_id }
  config.ip_resolver = -> { Current.ip }

  # O que entra no log.
  config.ignored_attributes = %i[created_at updated_at lock_version]
  config.masked_attributes += %i[token_api]
  config.mask_value = "[FILTRADO]"

  # Humanização.
  config.humanize_by_default = true
  config.i18n_scopes = ["activerecord.attributes", "attributes"]
  config.resolve_associations = true
  config.humanizer = nil

  # Falhas.
  config.raise_errors = Rails.env.test?
  config.error_handler = ->(error, record, action) { Rails.error.report(error, context: { action: action, record: record&.class&.name }) }
end
```

| Opção | Padrão | O que faz |
|---|---|---|
| `changed_by_id_resolver` | `nil` | Valor gravado em `changed_by_id` |
| `changed_by_type_resolver` | `nil` | Valor gravado em `changed_by_type` (classe, perfil, papel...) |
| `changed_by_other_resolver` | `-> { {} }` | Hash gravado em `changed_by_other` |
| `uuid_resolver` | `nil` | Uuid de correlação; sem valor, a gem gera um por log |
| `ip_resolver` | `nil` | Valor gravado em `ip_remote` |
| `ignored_attributes` | `created_at`, `updated_at`, `lock_version` | Campos que nunca entram no log |
| `masked_attributes` | `password`, `password_digest`, `encrypted_password`, `reset_password_token`, `confirmation_token`, `unlock_token` | Campos registrados sem o valor ([Campos sensíveis](#campos-sensíveis)) |
| `mask_value` | `"[FILTRADO]"` | Texto que substitui o valor mascarado |
| `humanize_by_default` | `true` | Gera o `audited_changes_humanize` |
| `i18n_scopes` | `["activerecord.attributes", "attributes"]` | Onde procurar a tradução dos campos |
| `resolve_associations` | `true` | Rótulo do registro em `belongs_to` ([Rótulo de associações](#rótulo-de-associações)) |
| `humanizer` | `nil` | Humanização personalizada ([Tradução dos campos](#tradução-dos-campos-i18n)) |
| `raise_errors` | `false` | Deixa o erro de gravação do log subir (útil em teste) |
| `error_handler` | `nil` | `->(error, record, action)` chamado quando gravar o log falha |

Todo resolver é um lambda. Se um resolver lançar erro, a gem registra um aviso e grava o campo vazio; o log não se perde por isso. Uma configuração inválida, como um valor que não é lambda, gera `AuditLogger::ConfigurationError` na subida do app.

## Quem fez a alteração (contexto do ator)

A gem não sabe sozinha quem está logado. O jeito mais comum é usar `ActiveSupport::CurrentAttributes`:

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :request_id, :ip
end
```

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base # ou ActionController::API
  before_action do
    Current.user = current_user # na API com JWT, o usuário que o token identificou
    Current.request_id = request.request_id
    Current.ip = request.remote_ip
  end
end
```

Com `uuid_resolver = -> { Current.request_id }`, todos os logs de uma mesma requisição ficam com o mesmo uuid. Por exemplo, salvar a pessoa e os contratos dela num formulário só.

Fora de requisição (jobs, rake, console), não há `Current.user`. O log é gravado com o ator vazio. Se quiser identificar a origem, preencha o `Current` no job.

## Auditando uma model

```ruby
class Pessoa < ApplicationRecord
  auditable
end
```

Opções, todas opcionais e válidas só para a model:

| Opção | Exemplo | O que faz |
|---|---|---|
| `ignored_attributes` | `[:sincronizado_em]` | Soma aos ignorados globais |
| `masked_attributes` | `[:token_generate]` | Soma aos mascarados globais |
| `owner` | `:pessoa` ou `->(r) { r.contrato&.pessoa }` | Registro dono do log ([Histórico de um agregado](#histórico-de-um-agregado-dono)) |
| `humanize` | `false` | Liga ou desliga a humanização nesta model |
| `i18n_scopes` | `["meu_app.campos", "activerecord.attributes"]` | Escopos de tradução próprios |
| `humanizer` | `->(klass, campo, antigo, novo) { ... }` | Humanização própria da model |

```ruby
class User < ApplicationRecord
  auditable masked_attributes: [:token_generate], ignored_attributes: [:last_sign_in_at]
end
```

## Consultando os logs

```ruby
pessoa.audit_logs                                  # logs do próprio registro
pessoa.audit_logs.where(action: "update").order(created_at: :desc)

AuditLogger::AuditLog.of_owner(pessoa)             # pessoa + registros que têm ela como dona
AuditLogger::AuditLog.where(model_class_name: "Contrato", action: "destroy")
AuditLogger::AuditLog.where(changed_by_id: user.id)
```

Para telas administrativas, filtros com Ransack ou scopes próprios, crie uma model no app que herda da model da gem:

```ruby
class AuditLog < AuditLogger::AuditLog
  scope :recentes, -> { order(created_at: :desc) }

  def self.ransackable_attributes(_auth = nil) = %w[model_class_name action changed_by_id created_at]
end
```

## Campos sensíveis

Pôr a senha em `ignored_attributes` faz a troca de senha sumir do histórico. Em `masked_attributes`, a alteração aparece, mas sem os valores:

```json
{ "type": "update", "fields": { "encrypted_password": { "old_value": "[FILTRADO]", "new_value": "[FILTRADO]" } } }
```

- O valor nulo continua nulo, para mostrar que o campo estava vazio.
- No `create`, um campo mascarado preenchido aparece como `"[FILTRADO]"`.
- Se um campo estiver nos ignorados e nos mascarados ao mesmo tempo, vale o ignorado.

## Histórico de um agregado (dono)

Cada log guarda um registro "dono" (`owner_type`/`owner_id`). Sem configuração, o dono é o próprio registro. Para juntar o histórico de várias models num lugar só:

```ruby
class Pessoa < ApplicationRecord
  auditable                                          # dona de si mesma
end

class Contrato < ApplicationRecord
  belongs_to :pessoa
  auditable owner: :pessoa                           # associação
end

class Dependente < ApplicationRecord
  belongs_to :contrato
  auditable owner: ->(dependente) { dependente.contrato&.pessoa }   # caminho mais longo
end

AuditLogger::AuditLog.of_owner(pessoa) # tudo da pessoa, do mais recente ao mais antigo
```

Se a associação do dono estiver vazia, o dono passa a ser o próprio registro. Com STI, o `owner_type` é a classe base.

## Rótulo de associações

Com `resolve_associations = true`, a troca de um `belongs_to` ganha no formato humanizado o nome do registro antigo e do novo:

```json
{ "label": "Cargo", "old_value": 3, "new_value": 7, "old_value_label": "PROFESSOR", "new_value_label": "ASSESSOR" }
```

No `create` e no `destroy`, o rótulo vai em `value_label`. Ele vem do `to_s` definido na model associada; se ela não tiver um, de `display_name`, `descricao`, `nome`, `name` ou `title`. A busca inclui registros excluídos por soft delete (`with_deleted`), porque o histórico precisa do nome antigo.

Cada rótulo custa uma consulta ao banco. Em tabelas com muitas associações e muita escrita, avalie desligar a opção na model (`humanize: false`) ou no global.

## Eventos manuais

O que não passa pelos callbacks da model é registrado com `AuditLogger.record_event`. É o caso do `update_all`, do login e do pedido de reset de senha.

```ruby
# Com um registro: usa a humanização e o dono da model dele.
AuditLogger.record_event(
  action: "password_reset_requested",
  record: user,
  fields: { encrypted_password: { old_value: "[FILTRADO]", new_value: "[FILTRADO]" } },
  metadata: { origem: "esqueci_minha_senha" }
)

# Sem registro (ex.: login de CPF que não existe).
AuditLogger.record_event(action: "login_failed", model_class_name: "User", id_object: cpf, metadata: { motivo: "senha" })

# Alteração em massa, com dono explícito.
ids = perfil.users.where(id: user_ids).pluck(:id)
perfil.users.where(id: ids).update_all(g_perfil_id: nil)
AuditLogger.record_event(action: "usuarios_desvinculados", record: perfil, metadata: { user_ids: ids })
```

| Parâmetro | Obrigatório | Conteúdo |
|---|---|---|
| `action` | sim | Nome do evento |
| `record` | não | Registro relacionado; define model, id e dono |
| `model_class_name`, `id_object` | não | Usados quando não há `record` |
| `owner` | não | Dono explícito (sobrepõe o da model) |
| `fields` | não | Mesmo formato do log automático |
| `metadata` | não | Hash livre, gravado em `audited_changes["metadata"]` |

## Falhas não derrubam a requisição

O log é gravado depois do commit, quando o dado do usuário já foi salvo. Se a gravação do log falhar (banco fora, JSON inválido, erro no humanizer), a gem:

1. registra o erro com `Rails.logger.error`;
2. chama o `error_handler`, se houver;
3. segue sem lançar exceção. A requisição não vira erro 500.

Em teste, use `config.raise_errors = true` para o erro aparecer.

## Formato dos dados

`audited_changes` (bruto) e `audited_changes_humanize` (humanizado) têm a mesma estrutura:

```jsonc
// create e destroy: retrato completo
{ "type": "create", "fields": { "nome": { "value": "Ana" }, "cargo_id": { "value": 3 } } }

// update: só o que mudou
{ "type": "update", "fields": { "nome": { "old_value": "Ana", "new_value": "Ana Maria" } } }

// evento manual
{ "type": "login_failed", "fields": {}, "metadata": { "motivo": "senha" } }
```

O humanizado acrescenta em cada campo:
- `label`: o nome traduzido;
- `old_value_label`, `new_value_label` ou `value_label`: o rótulo, nos campos de `belongs_to`.

## Tradução dos campos (I18n)

O `label` é procurado nesta ordem, para cada escopo de `i18n_scopes`:

1. `<escopo>.<model>.<campo>`, ex.: `activerecord.attributes.pessoa.nome`;
2. `<escopo>.<campo>`, ex.: `attributes.nome`.

Se não achar nada, usa `campo.humanize`.

```yaml
pt-BR:
  activerecord:
    attributes:
      pessoa:
        nome: "Nome"
        cargo_id: "Cargo"
```

Para controlar a apresentação de um campo, use um `humanizer`, global ou na model. Ele pode devolver:
- `nil`: usa a tradução padrão;
- um `Hash`: as chaves são mescladas ao campo (ex.: `{ label:, old_value:, new_value: }`);
- um valor simples: vira o `value` do campo.

```ruby
auditable humanizer: ->(_klass, campo, antigo, novo) do
  next unless campo == "situacao"

  { label: "Situação", old_value: SITUACOES[antigo], new_value: SITUACOES[novo] }
end
```

Uma falha no humanizer é registrada como aviso, e o campo cai na tradução padrão.

## Atualizando da 0.1.x

A 0.2.0 traz as colunas `owner_type` e `owner_id`. Para criá-las:

```bash
bin/rails generate audit_logger:upgrade
bin/rails db:migrate
```

Sem as colunas a gem continua funcionando; só não grava o dono. As demais novidades estão no [CHANGELOG](CHANGELOG.md):
- campos mascarados;
- falha segura;
- rótulos de associação;
- eventos manuais.

## Limitações e cuidados

- **Operações em massa não disparam callbacks.** `update_all`, `delete_all`, `insert_all`, `upsert_all` e `update_column(s)` não geram log; registre com `AuditLogger.record_event`.
- **Soft delete:**
  - com `paranoia`, o `destroy` dispara os callbacks de destroy, então confira no seu app se o `after_destroy_commit` é chamado;
  - com `discard`, a exclusão é um `update` e aparece como tal, com `discarded_at` mudando.
- **PostgreSQL:** a migration gerada usa `jsonb`. Nos testes da gem, as colunas são `text` em SQLite.
- **`url` e `user_agent`** não têm coluna própria: guarde em `changed_by_other`.

## Desenvolvimento

```bash
bin/setup
bundle exec rake test     # Minitest com SQLite em memória
bundle exec rubocop
bundle-audit check        # dependências com CVE
```

Para publicar uma versão:

1. Atualize `lib/audit_logger/version.rb` e o `CHANGELOG.md`.
2. Rode `bundle exec rake test`.
3. Gere o pacote com `gem build audit_logger.gemspec`.
4. Publique com `gem push audit_log_rails-<versão>.gem` (pede login e o código de verificação do RubyGems).
5. Crie a tag `v<versão>` no Git e envie: `git tag v<versão> && git push origin main --tags`.

## Licença

Código aberto sob a [licença MIT](LICENSE.txt).
