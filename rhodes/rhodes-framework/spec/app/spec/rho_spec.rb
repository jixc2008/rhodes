#
#  rho_spec.rb
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
require 'spec/spec_helper'

describe "Rho" do

  before(:each) do
    Rho::RhoConfig.config = {'start_path'=>'/app','options_path'=>'/app/Settings'}
  end
  
  it "should populate configuration in sources table" do
    sources = Rhom::RhomDbAdapter::select_from_table('sources','*')
    sources.size.should > 1
  end
  
  it "should have start_path" do
    Rho::RhoConfig.start_path.should == '/app'
  end
  
  it "should retrieve start_path" do
    Rho::RhoConfig.start_path.should == '/app'
  end
  
  it "should set start_path" do
    Rho::RhoConfig.config['start_path'] = '/foo/bar'
    Rho::RhoConfig.start_path.should == '/foo/bar'
  end
  
  it "should have options_path" do
    Rho::RhoConfig.options_path.should == '/app/Settings'
  end
  
  it "should set options_path" do
    Rho::RhoConfig.config['options_path'] = '/ops2'
    Rho::RhoConfig.options_path.should == '/ops2'
  end
end
