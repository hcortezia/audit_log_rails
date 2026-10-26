# AuditLogger

`AuditLogger` e uma gem Rails para auditar alteracoes em models ActiveRecord com:

- tabela propria de auditoria
- integracao simples por `auditable`
- payload bruto e payload humanizado
- configuracao global por initializer
- override por model

## Compatibilidade

No estado atual da gem, as versoes suportadas sao:

- Ruby `>= 3.1.0`
- Rails / ActiveRecord `>= 7.0` e `< 9.0`

Em outras palavras, a gem foi preparada para funcionar com projetos Rails 7 e Rails 8, desde que a versao do Ruby seja compativel.

## Visao Geral

Ao adicionar `auditable` em uma model, a gem registra eventos de:

- `create`
- `update`
- `destroy`

Os registros sao persistidos na tabela `audit_logs` com:

- identificacao da model auditada
- tipo da acao
- uuid de correlacao
- dados do ator que executou a acao
- payload bruto da alteracao
- payload humanizado para exibicao

## Instalacao Passo A Passo

Se esta for a primeira vez que voce vai usar a gem, siga exatamente esta ordem.

### Passo 1 - Adicionar a gem no projeto Rails

No `Gemfile` da aplicacao cliente, adicione:

```ruby
gem "audit_log_rails"
```

Observacao importante:

- o nome publicado da gem e `audit_log_rails`
- o namespace Ruby continua sendo `AuditLogger`
- por isso, no `Gemfile` voce instala `audit_log_rails`, mas no codigo continua usando `AuditLogger`

Depois rode:

```bash
bundle install
```

### Passo 2 - Gerar os arquivos iniciais da gem

Depois que a gem estiver instalada, rode:

```bash
bin/rails generate audit_logger:install
```

Esse comando e importante porque ele cria automaticamente os arquivos base que o projeto precisa para comecar.

### Passo 3 - Entender o que a gem criou

Ao rodar `bin/rails generate audit_logger:install`, a gem cria:

- `db/migrate/..._create_audit_logs.rb`
- `config/initializers/audit_logger.rb`

Ou seja:

- voce **nao precisa criar manualmente** o initializer da gem do zero
- voce **nao precisa escrever manualmente** a migration base do zero
- a gem ja entrega esses arquivos como ponto de partida

### Passo 4 - Rodar a migration

Depois que os arquivos forem gerados, rode:

```bash
bin/rails db:migrate
```

Esse comando cria a tabela `audit_logs` no banco da aplicacao.

### Passo 5 - Ajustar o initializer ao seu projeto

Depois que o arquivo `config/initializers/audit_logger.rb` for criado, voce deve abrir esse arquivo e adaptar os resolvers para a realidade do seu sistema.

Em outras palavras:

- a gem cria o arquivo para voce
- mas voce precisa ajustar o conteudo conforme seu `Current.user`, `Current.request`, sessao, perfis, tenants e assim por diante

## O Que O Generator Cria Na Pratica

### Migration

A migration criada pela gem prepara a tabela `audit_logs`, onde os registros de auditoria serao persistidos.

### Initializer

O initializer criado pela gem e o lugar onde voce diz:

- quem e o usuario atual
- qual id deve ser salvo em `changed_by_id`
- qual tipo deve ser salvo em `changed_by_type`
- quais metadados vao para `changed_by_other`
- como o `uuid` sera resolvido
- como o IP sera obtido
- quais atributos devem ser ignorados
- como a humanizacao deve funcionar

## Estrutura Da Tabela

A migration inicial cria a tabela `audit_logs` com os campos:

- `model_class_name`
- `id_object`
- `action`
- `uuid`
- `changed_by_id`
- `changed_by_type`
- `changed_by_other`
- `audited_changes`
- `audited_changes_humanize`
- `ip_remote`
- `owner_type` e `owner_id` (registro "dono", desde a 0.2.0)
- `created_at`
- `updated_at`
- `deleted_at`

Quem instalou a 0.1.x cria as colunas de dono com:

```bash
bin/rails generate audit_logger:upgrade
bin/rails db:migrate
```

Sem essas colunas a gem continua funcionando; so nao grava o dono.

## Configuracao Global Explicada

Depois de rodar o generator, a gem cria automaticamente o arquivo:

```text
config/initializers/audit_logger.rb
```

Voce nao precisa criar esse arquivo manualmente do zero.

O papel desse arquivo e ensinar a gem a descobrir informacoes do seu sistema.

Importante:

- esse arquivo e criado automaticamente pela gem quando voce roda o generator
- os exemplos relacionados a `Current.user`, `Current.request` e `Current.audit_uuid` sao apenas sugestoes
- voce precisa descomentar e adaptar somente o que fizer sentido no seu projeto

Se o seu sistema usa outro contexto, por exemplo `Current.admin`, `Current.account`, `session[:jwt]` ou qualquer outro objeto, basta trocar nos resolvers.

Exemplo do initializer:

```ruby
AuditLogger.configure do |config|
  # Descomente apenas o que fizer sentido no seu projeto.
  # A gem nao tem como adivinhar sozinha onde voce guarda usuario logado,
  # request, tenant, sessao ou token.

  # config.changed_by_id_resolver = -> { Current.user&.id }
  # config.changed_by_type_resolver = -> { Current.user&.class&.name }
  #
  # config.changed_by_other_resolver = lambda do
  #   {
  #     name: Current.user&.name,
  #     email: Current.user&.email,
  #     request_id: Current.request_id
  #   }.compact
  # end
  #
  # config.uuid_resolver = -> { Current.audit_uuid }
  # config.ip_resolver = -> { Current.request&.remote_ip }

  # humanize serve para utilizar traduções do i18n de forma que os attributes do model seja traduzidos humanizando a leitura.
  config.humanize_by_default = true

  # Configura o padrão do scope do i18n para a humanização dos atributos do model.
  config.i18n_scopes = ["activerecord.attributes", "attributes"]

  # Atributos que devem ser ignorados na auditoria.
  # Por exemplo, `created_at`, `updated_at`, `lock_version` e outros campos de auditoria.
  config.ignored_attributes = [:created_at, :updated_at, :lock_version]
  
  # Configura a humanização dos atributos do model.
  config.humanizer = ->(_model_klass, _attribute, _old_value, _new_value) { nil }
end
```

### O Que Esse Arquivo Faz

Esse bloco:

```ruby
AuditLogger.configure do |config|
  ...
end
```

serve para configurar o comportamento global da gem no projeto inteiro.

Tudo que estiver aqui vira o comportamento padrao da auditoria, a menos que uma model sobrescreva algo localmente.

### Explicando Cada Configuracao

#### `config.changed_by_id_resolver`

Exemplo:

```ruby
config.changed_by_id_resolver = -> { Current.user&.id }
```

Esse resolver diz para a gem qual valor deve ser salvo na coluna `changed_by_id`.

Na pratica:

- se o usuario logado for `Current.user`
- a gem vai salvar `Current.user.id`

Se no seu sistema o ator principal for outro, voce troca aqui.

Exemplo:

```ruby
config.changed_by_id_resolver = -> { Current.admin&.id }
```

#### `config.changed_by_type_resolver`

Exemplo:

```ruby
config.changed_by_type_resolver = -> { Current.user&.class&.name }
```

Esse resolver diz qual valor sera salvo em `changed_by_type`.

Voce pode usar isso para salvar:

- nome da classe
- perfil
- role
- tipo de usuario

Exemplo:

```ruby
config.changed_by_type_resolver = -> { Current.user&.profile }
```

#### `config.changed_by_other_resolver`

Exemplo:

```ruby
config.changed_by_other_resolver = lambda do
  {
    name: Current.user&.name,
    email: Current.user&.email,
    request_id: Current.request_id
  }.compact
end
```

Esse resolver preenche o campo `changed_by_other`, que e um JSON livre.

Use esse campo quando quiser guardar metadados extras, por exemplo:

- nome do usuario
- email
- request id
- tenant
- school_id
- url
- user_agent

Esse campo existe justamente para voce nao ficar preso so a `changed_by_id` e `changed_by_type`.

#### `config.uuid_resolver`

Exemplo:

```ruby
config.uuid_resolver = -> { Current.audit_uuid }
```

Esse resolver define o `uuid` do log.

Esse `uuid` e util para correlacionar varios logs da mesma sessao ou do mesmo fluxo.

Se esse resolver nao retornar valor, a gem gera um UUID automaticamente.

#### `config.ip_resolver`

Exemplo:

```ruby
config.ip_resolver = -> { Current.request&.remote_ip }
```

Esse resolver informa qual IP deve ser salvo em `ip_remote`.

Se voce nao quiser salvar IP, pode deixar `nil`.

#### `config.humanize_by_default`

Exemplo:

```ruby
config.humanize_by_default = true
```

Se estiver `true`, a gem tenta gerar `audited_changes_humanize` por padrao.

Se estiver `false`, a gem continua gravando o payload bruto, mas nao humaniza automaticamente.

#### `config.i18n_scopes`

Exemplo:

```ruby
config.i18n_scopes = ["activerecord.attributes", "attributes"]
```

Esses sao os escopos que a gem usa para tentar traduzir o nome dos atributos.

Por exemplo, ao auditar `Student.status`, a gem tenta procurar traducoes nesses caminhos.

#### `config.ignored_attributes`

Exemplo:

```ruby
config.ignored_attributes = [:created_at, :updated_at, :lock_version]
```

Aqui voce informa quais atributos nao devem entrar na auditoria por padrao.

Isso e util para evitar ruido.

#### `config.humanizer`

Exemplo:

```ruby
config.humanizer = ->(_model_klass, _attribute, _old_value, _new_value) { nil }
```

Esse e um humanizer global opcional.

Ele existe para casos em que voce quer controlar manualmente como um campo sera apresentado.

Importante:

- se ele retornar `nil`, a gem usa o fallback padrao com I18n
- se ele retornar um `Hash`, esse hash e usado para montar o payload humanizado
- se ele retornar um valor simples, a gem usa esse valor como representacao humanizada

## Exemplo Real Com `Current`

Uma forma comum de integrar a gem no app cliente e usar `CurrentAttributes`.

Se o seu projeto ainda nao tiver um `Current`, voce pode criar algo assim:

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :request, :audit_uuid, :request_id
end
```

Esse objeto serve como um lugar central para guardar o contexto atual da requisicao.

Depois, no controller base da aplicacao, voce pode preencher esses dados:

```ruby
class ApplicationController < ActionController::Base
  before_action :store_current_context

  private

  def store_current_context
    Current.user = current_user
    Current.request = request
    Current.request_id = request.request_id
    Current.audit_uuid ||= session[:audit_uuid] ||= SecureRandom.uuid
  end
end
```

O objetivo desse passo e simples:

- deixar `Current.user` disponivel para a gem
- deixar `Current.request` disponivel para a gem
- manter um `audit_uuid` estavel dentro da sessao

Se o seu sistema ja tiver outra estrategia para isso, nao precisa copiar exatamente esse exemplo.

## Ativando A Auditoria Na Model

Depois da instalacao e da configuracao global, voce ativa a auditoria na model com `auditable`.

Exemplo:

```ruby
class Student < ApplicationRecord
  auditable
end
```

So isso ja faz a gem registrar:

- criacao
- atualizacao
- remocao

## Consultando Os Logs Da Model

Ao usar `auditable`, a gem tambem define automaticamente a associacao:

```ruby
student.audit_logs
```

Ou seja, voce nao precisa criar manualmente um `has_many :audit_logs` basico para comecar.

Exemplo:

```ruby
student = Student.find(1)
student.audit_logs
```

Essa associacao ja filtra:

- `model_class_name`
- `id_object`

Assim, cada model passa a enxergar apenas os logs que pertencem a ela.

### Exemplo Pratico

```ruby
student = Student.create!(name: "Joao")

student.update!(name: "Maria")

student.audit_logs.count
# => 2
```

### Como A Associacao Funciona

A gem grava na tabela:

- `model_class_name`: nome da classe auditada, por exemplo `Student`
- `id_object`: id do registro auditado, salvo como string

Com isso, a associacao consegue ligar corretamente:

- a model atual
- ao id correto do objeto auditado

Se no futuro voce quiser um nome diferente para a associacao ou um escopo proprio, ainda pode sobrescrever isso manualmente no projeto cliente.

## Preciso Criar Uma Model No Projeto Cliente?

Para o uso basico, nao.

A gem ja fornece a model:

```ruby
AuditLogger::AuditLog
```

Entao, para comecar, voce pode usar:

- `self.audit_logs`
- `student.audit_logs`
- `AuditLogger::AuditLog.all`

## Uso Simples Com O Proprio Objeto

Se voce ja tem o objeto em maos e quer acessar os logs dele, o jeito mais simples e:

```ruby
self.audit_logs
```

Exemplo:

```ruby
student = Student.find(1)

student.audit_logs
student.audit_logs.where(action: "update")
student.audit_logs.order(created_at: :desc)
```

Esse e o caminho ideal quando voce quer:

- mostrar historico dentro da tela do proprio registro
- montar uma aba de auditoria no detalhe do objeto
- buscar apenas os logs daquele registro especifico

## Uso Avancado Para Relatorios, Rota E Ransack

Se voce quiser montar:

- relatorios gerais
- controllers e rotas proprias
- filtros com `ransack`
- telas administrativas
- scopes personalizados

ai vale a pena criar uma model no projeto cliente como wrapper da model da gem.

Exemplo:

```ruby
class AuditLog < AuditLogger::AuditLog
end
```

Isso nao substitui a model da gem.
Isso apenas cria um ponto de entrada mais natural dentro da sua aplicacao.

### Exemplo Com Scopes

```ruby
class AuditLog < AuditLogger::AuditLog
  scope :recent, -> { order(created_at: :desc) }
  scope :from_model, ->(model_name) { where(model_class_name: model_name) }
end
```

### Exemplo De Controller

```ruby
class AuditLogsController < ApplicationController
  def index
    @q = AuditLog.ransack(params[:q])
    @audit_logs = @q.result.order(created_at: :desc)
  end
end
```

### Exemplo De Rotas

```ruby
Rails.application.routes.draw do
  resources :audit_logs, only: [:index, :show]
end
```

### Exemplo De Consulta Geral

```ruby
AuditLog.where(model_class_name: "Student")
AuditLog.where(action: "update")
AuditLog.order(created_at: :desc)
```

## Regra Pratica

Se a necessidade for:

- historico do proprio registro: use `self.audit_logs`
- relatorio geral do sistema: use `AuditLogger::AuditLog`
- tela administrativa, filtro, `ransack`, rota propria: crie `AuditLog < AuditLogger::AuditLog`

## Sobrescrevendo Configuracao Em Uma Model

Se uma model precisar de comportamento diferente do padrao global, voce pode sobrescrever localmente.

Exemplo:

```ruby
class Student < ApplicationRecord
  auditable \
    humanize: true,
    i18n_scopes: ["school.student", "activerecord.attributes"],
    ignored_attributes: [:updated_at],
    humanizer: ->(_model_klass, attribute, old_value, new_value) do
      {
        label: "Campo #{attribute}",
        old_value: old_value,
        new_value: new_value
      }
    end
end
```

Nesse caso:

- a model usa `i18n_scopes` proprios
- ignora `updated_at` localmente
- pode ter um humanizer proprio so dela

## Como A Auditoria Funciona

A gem usa callbacks de commit:

- `after_create_commit`
- `after_update_commit`
- `after_destroy_commit`

Isso significa que o log so e gravado quando a transacao foi confirmada com sucesso.
Se houver rollback, a auditoria nao e persistida.

## Contrato Do Payload Bruto

### Create

Em `create`, a gem grava um snapshot completo dos atributos auditaveis:

```json
{
  "type": "create",
  "fields": {
    "name": {
      "value": "Joao"
    },
    "status": {
      "value": "active"
    }
  }
}
```

### Update

Em `update`, a gem grava apenas os campos alterados:

```json
{
  "type": "update",
  "fields": {
    "status": {
      "old_value": "active",
      "new_value": "inactive"
    }
  }
}
```

### Destroy

Em `destroy`, a gem grava um snapshot antes da remocao:

```json
{
  "type": "destroy",
  "fields": {
    "name": {
      "value": "Joao"
    },
    "status": {
      "value": "inactive"
    }
  }
}
```

## Contrato Do Payload Humanizado

O campo `audited_changes_humanize` segue a mesma estrutura do payload bruto, mas adiciona labels amigaveis:

```json
{
  "type": "update",
  "fields": {
    "status": {
      "label": "Situacao",
      "old_value": "active",
      "new_value": "inactive"
    }
  }
}
```

## Humanizacao Com I18n

Por padrao, a gem tenta buscar labels nesta ordem:

1. `activerecord.attributes.<model>.<attribute>`
2. `attributes.<attribute>`
3. fallback para `attribute.humanize`

Exemplo:

```yml
pt-BR:
  activerecord:
    attributes:
      student:
        name: "Nome"
        status: "Situacao"
  attributes:
    status: "Status"
```

## Metadados Extras Do Ator

O campo `changed_by_other` foi pensado para guardar metadados livres do ator e da requisicao, por exemplo:

```ruby
config.changed_by_other_resolver = lambda do
  {
    name: Current.user&.name,
    email: Current.user&.email,
    url: Current.request&.original_url,
    user_agent: Current.request&.user_agent,
    school_id: Current.school&.id
  }.compact
end
```

## Defaults Atuais Da Gem

Se voce nao configurar nada, a gem usa:

- `changed_by_other_resolver = -> { {} }`
- `humanize_by_default = true`
- `i18n_scopes = ["activerecord.attributes", "attributes"]`
- `ignored_attributes = [:created_at, :updated_at, :lock_version]`
- `masked_attributes = [:password, :password_digest, :encrypted_password, :reset_password_token, :confirmation_token, :unlock_token]`
- `mask_value = "[FILTRADO]"`
- `resolve_associations = true`
- `raise_errors = false`
- `error_handler = nil`

Se `uuid_resolver` nao retornar valor, a gem gera um UUID automaticamente.

## Campos Sensiveis (Mascarados)

Ignorar a senha (`ignored_attributes`) faz a troca de senha sumir do historico. Mascarar registra que o campo mudou, sem os valores:

```ruby
# global (initializer)
config.masked_attributes += [:token_api]

# por model
class User < ApplicationRecord
  auditable masked_attributes: [:token_generate]
end
```

No payload, `old_value` e `new_value` viram `"[FILTRADO]"`. Valor nulo continua nulo, para mostrar que o campo estava vazio.

## Falhas Nao Derrubam A Requisicao

O log e gravado depois do commit. Se a gravacao do log falhar, a gem registra o erro (`Rails.logger.error`), chama o `error_handler` (se houver) e segue: o dado do usuario ja foi salvo e a requisicao nao vira erro 500.

```ruby
config.error_handler = ->(error, record, action) { Sentry.capture_exception(error) }
config.raise_errors = Rails.env.test? # nos testes, o erro sobe
```

## Historico De Um Agregado (Dono)

Cada log guarda um registro "dono". Sem configuracao, o dono e o proprio registro. Para juntar o historico de varias models num registro so (ex.: a pessoa, os contratos e os dependentes dela):

```ruby
class Contrato < ApplicationRecord
  belongs_to :pessoa
  auditable owner: :pessoa
end

class Dependente < ApplicationRecord
  auditable owner: ->(dependente) { dependente.contrato&.pessoa }
end

AuditLogger::AuditLog.of_owner(pessoa) # pessoa + contratos + dependentes, do mais recente ao mais antigo
```

## Rotulo De Associacoes

Com `resolve_associations = true`, a troca de um `belongs_to` traz no payload humanizado o rotulo do registro associado:

```json
{ "label": "Cargo", "old_value": 3, "new_value": 7, "old_value_label": "PROFESSOR", "new_value_label": "ASSESSOR" }
```

O rotulo vem do `to_s` definido na model associada ou, na falta dele, de `display_name`, `descricao`, `nome`, `name` ou `title`. Registros com soft delete (`with_deleted`) tambem sao encontrados.

## Eventos Manuais

Para o que nao passa pelos callbacks (`update_all`, pedido de reset de senha, login):

```ruby
AuditLogger.record_event(
  action: "password_reset_requested",
  record: user,
  fields: { encrypted_password: { old_value: "[FILTRADO]", new_value: "[FILTRADO]" } },
  metadata: { origem: "esqueci_minha_senha" }
)

AuditLogger.record_event(action: "login_failed", model_class_name: "User", id_object: cpf, metadata: { motivo: "senha" })
```

Como no log automatico, uma falha aqui nunca sobe (a nao ser com `raise_errors`).

## Limitacoes Atuais

- a migration usa `jsonb`, entao o uso esperado em producao e com PostgreSQL
- nos testes da gem, esses campos foram simulados com `text` em SQLite em memoria
- `url` e `user_agent` ainda nao possuem colunas proprias; hoje o recomendado e armazenar isso em `changed_by_other`

## Desenvolvimento

Depois de clonar o repositorio:

```bash
bin/setup
bundle install
bundle exec rake test
```

## Testes

A gem usa:

- `Minitest`
- `ActiveRecord`
- `SQLite` em memoria para a suite local

Para rodar os testes:

```bash
bundle exec rake test
```

## Proximos Passos Sugeridos

- refinar README com mais exemplos por dominio
- adicionar testes especificos de rollback
- documentar estrategias para soft delete
- melhorar metadata publica da gem no `gemspec`

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
