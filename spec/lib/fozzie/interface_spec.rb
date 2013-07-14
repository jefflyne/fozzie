require 'spec_helper'

describe Fozzie::Interface do
  
  subject { Class.new() { extend Fozzie::Interface } }
  
  it "#increment" do
    subject.should_receive(:send).with('wat', 1, :count, 1)
    subject.increment 'wat'
  end

  it "#decrement" do
    subject.should_receive(:send).with('wat', -1, :count, 1)
    subject.decrement 'wat'
  end

  it "#count" do
    subject.should_receive(:send).with('wat', 5, :count, 1)
    subject.count 'wat', 5
  end

  it "#timing" do
    subject.should_receive(:send).with('wat', 500, :timing, 1)
    subject.timing 'wat', 500
  end

  it "times a given block" do
    subject.should_receive(:timing).with do |b, val, timing|
      b == 'data.bin' && (1..11).include?(val)
    end.exactly(3).times

    subject.time_for('data.bin')   { sleep 0.01 }
    subject.time_to_do('data.bin') { sleep 0.01 }
    subject.time('data.bin')       { sleep 0.01 }
  end

  describe "event" do
    it "for a commit" do
      subject.should_receive(:gauge).with(['event', 'commit', nil], anything).twice
      subject.commit
      subject.committed
    end

    it "for a build" do
      subject.should_receive(:gauge).with(['event', 'build', nil], anything).twice
      subject.build
      subject.built
    end

    it "for a deploy" do
      subject.should_receive(:gauge).with(['event', 'deploy', nil], anything).twice
      subject.deploy
      subject.deployed
    end

    it "for anything" do
      subject.should_receive(:send).with(['event', 'foo', nil], anything, :gauge, 1)
      subject.event 'foo'
    end

    it "accepts an app name" do
      subject.should_receive(:send).with(['event', 'foo', 'fozzie'], anything, :gauge, 1)
      subject.event 'foo', 'fozzie'
    end
  end

  describe "#increment_on" do
    it "registers success" do
      subject.should_receive(:increment).with(["event.increment", "success"], 1)
      subject.increment_on('event.increment', true).should == true
    end

    it "registers failure" do
      subject.should_receive(:increment).with(["event.increment", "fail"], 1)
      subject.increment_on('event.increment', false).should == false
    end

    it "simply questions the passed val with if" do
      a = mock
      a.should_receive(:save).and_return({})
      subject.should_receive(:increment).with(["event.increment", "success"], 1)
      subject.increment_on('event.increment', a.save).should == {}
    end

    it "registers fail on nil return" do
      a = mock
      a.should_receive(:save).and_return(nil)
      subject.should_receive(:increment).with(["event.increment", "fail"], 1)
      subject.increment_on('event.increment', a.save).should == nil
    end

    describe "performing actions" do
      it "registers success" do
        a = mock
        a.should_receive(:save).and_return(true)
        subject.should_receive(:increment).with(["event.increment", "success"], 1)
        subject.increment_on('event.increment', a.save).should == true
      end

      it "registers failure" do
        a = mock
        a.should_receive(:save).and_return(false)
        subject.should_receive(:increment).with(["event.increment", "fail"], 1)
        subject.increment_on('event.increment', a.save).should == false
      end

      it "registers positive even when nested" do
        a = mock
        a.should_receive(:save).and_return(true)
        subject.should_receive(:timing).with('event.run', anything, anything)
        subject.should_receive(:increment).with(["event.increment", "success"], 1)

        res = subject.time_to_do "event.run" do
          subject.increment_on('event.increment', a.save)
        end
        res.should == true
      end

      it "registers negative even when nested" do
        a = mock
        a.should_receive(:save).and_return(false)
        subject.should_receive(:timing).with('event.run', anything, anything)
        subject.should_receive(:increment).with(["event.increment", "fail"], 1)

        res = subject.time_to_do "event.run" do
          subject.increment_on('event.increment', a.save)
        end
        res.should == false
      end
    end
  end

  it "registers a gauge measurement" do
    subject.should_receive(:send).with("mystat", 99, :gauge, 1)
    subject.gauge("mystat", 99)
  end

  it "#histogram" do
    subject.should_receive(:send).with('mystat', 99, :histogram, 1)
    subject.histogram('mystat', 99)
  end
  
  context "exceptions" do
    
    before(:each) { Fozzie.stub(:log) } # Quieten the logs
    
    it "returns false for bad socket return value length" do
      UDPSocket.any_instance.stub(:send).and_return('3')
      subject.increment('foo').should eq(false)
    end
  
    it "raises exception if natural exception from block" do
      proc { 
        subject.time_to_do('data.bin', 1, :gauge, 1) { raise ArgumentError, "testing" } 
      }.should raise_error(ArgumentError)
    end

    it "only calls the block once on error" do
      UDPSocket.any_instance.stub(:send) { raise SocketError }
      i = 0
      p = proc {|n| (n + 1) }
      val = subject.time_to_do('data.bin') { i+= p.call(i) }

      val.should == 1
    end

    it "raises Timeout on slow lookup" do
      Timeout.stub(:timeout).with(any_args) { raise(Timeout::Error) }

      subject.increment('bar').should eq(false)
    end
  end

end