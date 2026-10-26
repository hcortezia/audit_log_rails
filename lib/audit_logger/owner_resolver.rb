# frozen_string_literal: true

module AuditLogger
  # Descobre o registro "dono" do log, para consultar o historico de um agregado num lugar so
  # (ex.: alteracoes da pessoa, dos contratos e dos dependentes dela).
  class OwnerResolver
    def self.call(record, model_config)
      new(record, model_config).call
    end

    def initialize(record, model_config)
      @record = record
      @model_config = model_config
    end

    # Sem owner configurado, ou com associacao vazia, o dono e o proprio registro.
    def call
      attributes_for(resolve_owner || record)
    end

    # Atributos owner_type/owner_id de um registro qualquer (tambem usado por record_event).
    def self.attributes_for(owner)
      return {} if owner.nil?

      klass = owner.class
      type = klass.respond_to?(:base_class) ? klass.base_class.name : klass.name
      { owner_type: type, owner_id: owner.id.to_s }
    end

    private

    attr_reader :record, :model_config

    def resolve_owner
      case model_config.owner
      when Symbol then record.public_send(model_config.owner)
      when Proc then model_config.owner.call(record)
      end
    end

    def attributes_for(owner)
      self.class.attributes_for(owner)
    end
  end
end
