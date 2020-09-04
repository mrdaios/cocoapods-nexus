require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Command::Nexus do
    describe 'CLAide' do
      it 'registers it self' do
        Command.parse(%w{ nexus }).should.be.instance_of Command::Nexus
      end
    end
  end
end

