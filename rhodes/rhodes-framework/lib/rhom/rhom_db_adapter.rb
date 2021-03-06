#
#  rhom_db_adapter.rb
#  rhodes
#
#  Copyright (C) 2008 Rhomobile, Inc. All rights reserved.
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#$:.unshift(File.join(File.dirname(__FILE__), '../../'))
# require 'sqlite3/database'
require 'rhodes'

module Rhom
  class RhomDbAdapter
    
    @@database = nil
    
    class << self
      
      # maintains a single database connection
      def open(dbfile=nil)
        #puts "DB name = " + dbfile.inspect
        unless @@database or dbfile.nil?
          @@database = SQLite3::Database.new(dbfile)
        end
      end
    
      # closes the database if and only if it is open
      def close
        if @@database #and not @@database.closed?
          @@database.close
          @@database = nil
        else
          return false
        end
        return true
      end   
    
      # execute a sql statement
      # optionally, disable the factory processing 
      # which returns the result array directly
      def execute_sql(sql=nil)
        result = []
        if sql
          #puts 'query is ' + sql
          # Make sure we lock the sync engine's mutex
          # before we perform a database transaction.
          # This prevents concurrency issues.
          begin
            SyncEngine::lock_sync_mutex
            # execute sql statement inside of transaction
            # result is returned as an array of hashes
            # @@database.transaction unless @@database.transaction_active?
            # @@database.results_as_hash = true
            result = @@database.execute sql
            # @@database.commit
            SyncEngine::unlock_sync_mutex
          rescue Exception => e
            puts "exception when running query: #{e}"
            # make sure we unlock even if there's an error!
            SyncEngine::unlock_sync_mutex
          end
        end
        #puts "returned #{result.length.to_s} records..."
        result
      end
    
      # generates where clause based on hash
      def where_str(condition,select_arr=nil)
        where_str = ""
        if condition
          where_str += string_from_key_vals(condition,"and")
          where_str = where_str[0..where_str.length - 5]
        end
        
        if select_arr and select_arr.length > 0
          where_str += " and attrib in (#{select_str(select_arr)})"
        end
        #puts "where_str: #{where_str}" if where_str
        where_str
      end
      
      def select_str(select_arr)
        select_str = ""
        select_arr.each do |attrib|
          select_str << "'#{attrib}'" + ","
        end
        select_str.length > 2 ? select_str[0..select_str.length-2] : select_str
      end
    
      # generates value clause based on hash
      def vals_str(values)
        vals = string_from_key_vals(values, ",")
        vals[0..vals.length - 2]
      end
      
      # generates key/value list
      def string_from_key_vals(values, delim)
        vals = ""
        values.each do |key,value|
          vals << " #{key} = #{get_value_for_sql_stmt(value)} #{delim}"
        end
        vals
      end
      
      # generates a value for sql statement
      def get_value_for_sql_stmt(value)
        if value.is_a?(String)
          "'#{value}'"
        elsif value.nil?
          "NULL"
        else
          "#{value}"
        end
      end
    
      # support for select statements
      # this function takes table name, columns (as a comma-separated list),
      # condition (as a hash), and params (as a hash)
      # example usage is the following:
      # select_from_table('object_values', '*', {"source_id"=>2,"update_type"=>'query'},
      #                   {"order by"=>'object'})
      # this would return all columns where source_id = 2 and update_type = 'query' ordered
      # by the "object" column
      def select_from_table(table=nil,columns=nil,condition=nil,params=nil,select_arr=nil)
        query = nil
        if table and columns and condition
          if params and params['distinct']
            query = "select distinct #{columns} from #{table} where #{where_str(condition,select_arr)}"
          elsif params and params['order by']
            query = "select #{columns} from #{table} where #{where_str(condition,select_arr)} order by #{params['order by']}"
          else
            query = "select #{columns} from #{table} where #{where_str(condition,select_arr)}"
          end
        elsif table and columns
          query = "select #{columns} from #{table}"                     
        end
        execute_sql query
      end
    
      # inserts a single row into the database
      # takes the table name and values (hash) as arguments
      # exmaple usage is the following:
      # insert_into_table('object_values, {"source_id"=>1,"object"=>"some-object","update_type"=>'delete'})
      # this would execute the following sql:
      # insert into object_values (source_id,object,update_type) values (1,'some-object','delete');
      def insert_into_table(table=nil,values=nil)
        query = nil
        cols = ""
        vals = ""
        if table and values
          values.each do |key,val|
            value = get_value_for_sql_stmt(val)+","
            cols << "#{key},"
            vals << value
          end
          cols = cols[0..cols.length - 2]
          vals = vals[0..vals.length - 2]
          query = "insert into #{table} (#{cols}) values (#{vals})"
        end
        execute_sql query
      end
    
      # deletes rows from a table which satisfy condition (hash)
      # example usage is the following:
      # delete_from_table('object_values',{"object"=>"some-object"})
      # this would execute the following sql:
      # delete from object_values where object="some-object"
      def delete_from_table(table=nil,condition=nil)
        query = nil
        if table and condition
          query = "delete from #{table} where #{where_str(condition)}"
        end
        execute_sql query
      end
    
      # deletes all rows from a given table
      def delete_all_from_table(table=nil)
        query = nil
        if table
          query = "delete from #{table}"
        end
        execute_sql query
      end
    
      # updates values (hash) in a given table which satisfy condition (hash)
      # example usage is the following:
      # update_into_table('object_values',{"value"=>"Electronics"},{"object"=>"some-object", "attrib"=>"industry"})
      # this executes the following sql:
      # update table object_values set value='Electronics' where object='some-object' and attrib='industry';
      def update_into_table(table=nil,values=nil,condition=nil)
        query = nil
        vals = values.nil? ? nil : vals_str(values)
        if table and condition and vals
          query = "update #{table} set #{vals} where #{where_str(condition)}"
        end
        execute_sql query
      end
    end # class methods
  end # RhomDbAdapter
end # Rhom

at_exit do
	Rhom::RhomDbAdapter::close
end
