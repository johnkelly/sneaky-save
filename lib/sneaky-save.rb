#--
# Copyright (c) 2011 {PartyEarth LLC}[http://partyearth.com]
# mailto:kgoslar@partyearth.com
#++
module SneakySave

  # Saves record without running callbacks/validations.
  # Returns true if any record is changed.
  # @note - Does not reload updated record by default.
  #       - Does not save associated collections.
  #       - Saves only belongs_to relations.
  #
  # @return [false, true]
  def sneaky_save
    begin
      sneaky_create_or_update
    rescue ActiveRecord::StatementInvalid
      false
    end
  end

  # Saves the record raising an exception if it fails.
  # @return [true] if save was successful.
  # @raise [ActiveRecord::StatementInvalid] if save failed.
  def sneaky_save!
    sneaky_create_or_update
  end


  # Provide a public method to overwrite attribute names
  # for compatibility with gems that overwrite attribute_names
  def sneaky_attribute_names
    attribute_names
  end

  # Provide a public method to overwrite attribute
  # for compatibility with gems that overwrite attributes
  def sneaky_attributes
    attributes
  end

  protected

    def sneaky_create_or_update
      new_record? ? sneaky_create : sneaky_update
    end

    # Makes INSERT query in database without running any callbacks
    # @return [false, true]
    def sneaky_create
      if self.id.nil? && sneaky_connection.prefetch_primary_key?(self.class.table_name)
        self.id = sneaky_connection.next_sequence_value(self.class.sequence_name)
      end

      attributes_values = sneaky_attributes_values

      # Remove the id field for databases like Postgres which will raise an error on id being NULL
      if self.id.nil? && !sneaky_connection.prefetch_primary_key?(self.class.table_name)
        attributes_values.reject! { |key,_| key.name == 'id' }
      end

      new_id = if attributes_values.empty?
        self.class.unscoped.insert sneaky_connection.empty_insert_statement_value
      else
        self.class.unscoped.insert attributes_values
      end

      @new_record = false
      !!(self.id ||= new_id)
    end

    # Makes update query without running callbacks
    # @return [false, true]
    def sneaky_update

      # Handle no changes.
      return true if changes.empty?

      # Here we have changes --> save them.
      pk = self.class.primary_key
      original_id = changed_attributes.has_key?(pk) ? changes[pk].first : send(pk)
      !self.class.where(pk => original_id).update_all(sneaky_attributes).zero?
    end

    def sneaky_attributes_values
      if ActiveRecord::VERSION::STRING.split('.').first.to_i > 3
        send :arel_attributes_with_values_for_create, sneaky_attribute_names
      else
        send :arel_attributes_values
      end
    end

    def sneaky_connection
      if ActiveRecord::VERSION::STRING.split('.').first.to_i > 3
        self.class.connection
      else
        connection
      end
    end
end

ActiveRecord::Base.send :include, SneakySave
