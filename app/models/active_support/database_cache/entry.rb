module ActiveSupport::DatabaseCache
  class Entry < Record
    class << self
      def set(key, value, expires_at: nil)
        upsert_all([{key: key, value: value, expires_at: expires_at}], unique_by: upsert_unique_by, update_only: [:value, :expires_at])
      end

      def set_all(payloads, expires_at: nil)
        upsert_all(payloads, unique_by: upsert_unique_by, update_only: [:value, :expires_at])
      end

      def get(key)
        where(key: key).pick(:id, :value)
      end

      def get_all(keys)
        rows = where(key: keys).pluck(:key, :id, :value)
        rows.to_h { |row| [ row[0], row[1..2] ] }
      end

      def delete(key)
        where(key: key).delete_all.nonzero?
      end

      def delete_matched(matcher, batch_size:)
        like_matcher = arel_table[:key].matches(matcher, nil, true)
        where(like_matcher).select(:id).find_in_batches(batch_size: batch_size) do |entries|
          delete_by(id: entries.map(&:id))
        end
      end

      def increment(key, amount)
        transaction do
          amount += lock.where(key: key).pick(:value).to_i
          set(key, amount)
          amount
        end
      end

      def touch_by_ids(ids)
        where(id: ids).touch_all
      end

      private
        def upsert_unique_by
          connection.supports_insert_conflict_target? ? :key : nil
        end
    end
  end
end

ActiveSupport.run_load_hooks :active_support_database_cache_entry, ActiveSupport::DatabaseCache::Entry

