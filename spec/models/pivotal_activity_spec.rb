require 'spec_helper'

describe PivotalActivity do
  let :payload_file do
    File.join(Rails.root, '/spec/support/fixtures/sample_pivotal_payload.xml')
  end

  let :payload_string do
    File.open(payload_file).read
  end

  let :params do
    Hash.from_xml(payload_string).deep_symbolize_keys[:activity]
  end

  let! :project do FactoryGirl.create(:project, :pivotal_id => 833075) end
  let! :user do
    FactoryGirl.create(:user, :pivotal_name => "Hannah Howard")
  end

  let :start_time do DateTime.parse("Mon, 27 May 2013 06:25:17 +0000").advance(:minutes => -15) end
  let :stop_time do DateTime.parse("Mon, 27 May 2013 06:25:17 +0000").advance(:minutes => 5) end

  let :last_activity do Activity.last end

  describe "save" do
    it "should create an activity" do
      expect do
        pivotal_activity = PivotalActivity.new(params)
        pivotal_activity.save
      end.to change{Activity.count}.by(1)
    end

    it "should set the parameters properly" do
      pivotal_activity = PivotalActivity.new(params)
      pivotal_activity.save
      last_activity.source.should == "pivotal"
      last_activity.action.should == "story_create"
      last_activity.description.should == "Hannah Howard added \"Testing Awesomeness\""
      last_activity.time.should == DateTime.parse("Mon, 27 May 2013 06:25:17 +0000").to_s
      last_activity.properties['story_id'].should == "50584573"
      last_activity.properties['current_state'].should == "unscheduled"
      last_activity.project.should == project
      last_activity.user.should == user
    end

    describe "with an closed work unit" do
      let! :work_unit do
        FactoryGirl.create(:work_unit,
                           start_time: start_time,
                           stop_time: stop_time,
                           hours: 0.3,
                           user: user,
                           project: project)
      end

      it "should associate the activity with the work unit" do
        pivotal_activity = PivotalActivity.new(params)
        pivotal_activity.save

        last_activity.work_unit.should == work_unit
      end
    end

    describe "with an in-progress work unit" do
      let! :work_unit do
        FactoryGirl.create(:in_progress_work_unit,
                           start_time: start_time,
                           user: user,
                           project: project)
      end
      it "should associate the activity with the work unit" do
        pivotal_activity = PivotalActivity.new(params)
        pivotal_activity.save

        last_activity.work_unit.should == work_unit
      end
    end

    describe "with an inapplicable work unit" do
      let! :work_unit do
        FactoryGirl.create(:work_unit,
                           start_time: DateTime.parse("Mon, 27 May 2013 06:25:17 +0000").
                                                advance(:minutes => -45),
                           stop_time: DateTime.parse("Mon, 27 May 2013 06:25:17 +0000").
                                               advance(:minutes => -15),
                           hours: 0.3,
                           user: user,
                           project: project)
      end

      it "should not associate the activity with the work unit" do
        pivotal_activity = PivotalActivity.new(params)
        pivotal_activity.save

        last_activity.work_unit.should == nil
      end
    end
  end

end
