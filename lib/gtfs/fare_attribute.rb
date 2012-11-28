module GTFS
  class FareAttribute
    include GTFS::Model

    has_required_attrs :fare_id, :price, :currency_type, :payment_method, :transfers
    has_optional_attrs :transfer_duration
    attr_accessor *attrs

    collection_name :fare_attribtues
    required_file false
    uses_filename 'fare_attributes.txt'

    def self.parse_fare_attributes(data)
      return parse_models(data)
    end
  end
end