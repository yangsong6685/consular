require File.expand_path('../teststrap', __FILE__)

context "Terminitor" do
  setup do
    @yaml = File.read(File.expand_path('../fixtures/foo.yml', __FILE__))
    @template = File.read(File.expand_path('../../lib/templates/example.yml.tt', __FILE__))
    FakeFS.activate!
    FileUtils.mkdir_p(File.join(ENV["HOME"],'.terminitor'))
  end
  teardown  { FakeFS.deactivate! }

  context "help" do
    setup { capture(:stdout) { Terminitor::Cli.start(['-h']) } }
    asserts_topic.matches %r{start PROJECT_NAME}
    asserts_topic.matches %r{init}
    asserts_topic.matches %r{edit PROJECT_NAME}
  end

  context "list" do
    setup do
      @path = "#{ENV['HOME']}/.terminitor/"
      File.open(File.join(@path,'foo.yml'),"w") { |f| f.puts @template }
      File.open(File.join(@path,'bar.yml'),"w") { |f| f.puts @template }
      capture(:stdout) { Terminitor::Cli.start(['list']) }
    end
    asserts_topic.matches %r{foo\.yml - COMMENT OF SCRIPT HERE}
    asserts_topic.matches %r{bar\.yml - COMMENT OF SCRIPT HERE}
  end

  asserts "#init creates .terminitor" do
    capture(:stdout) { Terminitor::Cli.start(['init']) }
    File.exists?("#{ENV['HOME']}/.terminitor")
  end

  context "edit" do
    setup do
      FakeFS.deactivate!
      `rm -rf #{ENV['HOME']}/.terminitor/test_foo_bar2.yml`
      `rm -rf #{ENV['HOME']}/.terminitor/test_foo_bar2.term`
    end

    teardown  do
      `rm -rf /tmp/sample_project`
      `rm -rf #{ENV['HOME']}/.terminitor/test_foo_bar2.yml`
      `rm -rf #{ENV['HOME']}/.terminitor/test_foo_bar2.term`
    end

    context "for project" do

      context "for yaml" do
        setup do 
          capture(:stdout) do
            mock.instance_of(Terminitor::Cli).open_in_editor("#{ENV['HOME']}/.terminitor/test_foo_bar2.yml",nil) { true }.once
            Terminitor::Cli.start(['edit','test_foo_bar2', '-s=yml'])
          end
        end
        asserts_topic.matches %r{create}
        asserts_topic.matches %r{test_foo_bar2.yml}
        asserts("has yml template") { File.read(File.join(ENV['HOME'],'.terminitor','test_foo_bar2.yml')) }.matches %r{- tab1}
      end

      context "for term" do
        setup do
          capture(:stdout) do
            mock.instance_of(Terminitor::Cli).open_in_editor("#{ENV['HOME']}/.terminitor/test_foo_bar2.term",nil) { true }.once
            Terminitor::Cli.start(['edit','test_foo_bar2', '-s=term'])
          end
        end
        asserts_topic.matches %r{create}
        asserts_topic.matches %r{test_foo_bar2.term}
        asserts("has term template") { File.read(File.join(ENV['HOME'],'.terminitor','test_foo_bar2.term')) }.matches %r{setup}
      end

    end

    context "for Termfile" do
      setup do
        capture(:stdout) do
          mock.instance_of(Terminitor::Cli).open_in_editor("/tmp/sample_project/Termfile",nil) { true }.once
          Terminitor::Cli.start ['edit','-s=yml','-r=/tmp/sample_project']
        end
      end
      asserts_topic.matches %r{create}
      asserts_topic.matches %r{Termfile}
      asserts("has term template") { File.read('/tmp/sample_project/Termfile') }.matches %r{setup}
    end

    should "accept editor flag" do
      FileUtils.mkdir_p('/tmp/sample_project')
      capture(:stdout) do 
        mock.instance_of(Terminitor::Cli).open_in_editor('/tmp/sample_project/Termfile','nano') { true }.once
        Terminitor::Cli.start(['edit','-r=/tmp/sample_project','-c=nano'])
      end
    end
    
    context "for capture flag" do

      asserts "yaml returns a message that" do 
        capture(:stdout) { Terminitor::Cli.start(['edit','foobar', '-s=yml', '--capture']) }
      end.matches %r{Terminal settings can be captured only to DSL format.}
      
      context "for term" do

        asserts "with no core returns a message that" do
          capture(:stdout) do
            mock.instance_of(Terminitor::Cli).capture_core(anything) { nil }
            FileUtils.touch("#{ENV['HOME']}/.terminitor/delete_this.term")
            Terminitor::Cli.start(['edit', 'test_foo_bar2', '--capture'])
          end
        end.matches %r{No suitable core found!}


        asserts "with core that it executes" do
          mock.instance_of(Terminitor::Cli).capture_core(anything) { mock!.new.mock!.capture_settings { "settings"} }
          mock.instance_of(Terminitor::Cli).open_in_editor("#{ENV['HOME']}/.terminitor/test_foo_bar2.term",nil) { true }
          Terminitor::Cli.start(['edit','test_foo_bar2', '--capture'])
        end

      end
    end

  end

  asserts "#create calls edit" do
    capture(:stdout) do
      mock.instance_of(Terminitor::Cli).invoke(:edit, [], 'root' => '/tmp/sample_project') { true }.once
      Terminitor::Cli.start(['create','-r=/tmp/sample_project'])
    end
  end

  asserts "#open returns a message that" do
    capture(:stdout) do
      mock.instance_of(Terminitor::Cli).invoke(:edit, [""], {'syntax' => 'term', 'root' => '/tmp/sample_project'}) { true }.once
      Terminitor::Cli.start(['open','-r=/tmp/sample_project'])
    end
  end.matches %r{'open' is now deprecated. Please use 'edit' instead}

  context "#delete" do
    denies "Termfile exists" do
      FileUtils.mkdir_p '/tmp/sample_project'
      FileUtils.touch "/tmp/sample_project/Termfile"
      capture(:stdout) { Terminitor::Cli.start(['delete',"-r=/tmp/sample_project"]) }
      File.exists? "/tmp/sample_project/Termfile"
    end

    denies "yaml exists" do
      FileUtils.touch "#{ENV['HOME']}/.terminitor/delete_this.yml"
      capture(:stdout) { Terminitor::Cli.start(['delete','delete_this', '-s=yml']) }
      File.exists? "#{ENV['HOME']}/.terminitor/delete_this.yml"
    end

    denies "term exists" do
      FileUtils.touch "#{ENV['HOME']}/.terminitor/delete_this.term"
      capture(:stdout) { Terminitor::Cli.start(['delete','delete_this']) }
      File.exists? "#{ENV['HOME']}/.terminitor/delete_this.term"
    end
  end

  asserts "#setup calls #execute_core" do
    capture(:stdout) do
      mock.instance_of(Terminitor::Cli).execute_core(:setup!,'project') { true }
      Terminitor::Cli.start(['setup','project'])
    end
  end


  asserts "#start calls #execute_core" do
    capture(:stdout) do
      mock.instance_of(Terminitor::Cli).execute_core(:process!,'project') { true }
      Terminitor::Cli.start(['start','project'])
    end
  end
  
  asserts "#fetch runs setup in project diretory" do
    capture(:stdout) do
      mock.instance_of(Terminitor::Cli).github_repo('achiu','terminitor', 'root' => '.', 'setup' => true) { true }
      Terminitor::Cli.start ['fetch','achiu','terminitor']
    end
  end
end
