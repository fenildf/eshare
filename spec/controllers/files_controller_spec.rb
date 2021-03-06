require 'spec_helper'

describe 'Issue #8 #9' do
  it {
    FileEntity.create :attach_file_name => 'abc.test',
                      :attach_file_size => 1234
    FileEntity.last.saved_size.should == 0
  }
end

describe FilesController do
  describe 'POST #upload' do
    before {
      @blob = ActionDispatch::Http::UploadedFile.new({
        :filename => 'blob',
        :type => 'text/html',
        :tempfile => File.new(Rails.root.join('spec/data/upload_test_files/test1024.file'))
      })
    }

    context '参数不正确，异常情况' do
      before {
        sign_in(FactoryGirl.create(:user))
        post :upload, :aaa => 'bbb',
                      :blob => 'foobar'

      }

      it {
        response.code.should == '500'
      }

      it {
        response.body.should == 'params or other error.'
      }

      it {
        FileEntity.count.should == 0
      }
    end

    context '上传一个新文件' do
      before do
        sign_in(FactoryGirl.create(:user))
        post :upload, :file_name  => 'test.zip',
                      :file_size  => 62614734,
                      :start_byte => 0,
                      :blob       => @blob
        @json = JSON::parse(response.body)
      end

      it { response.should be_success }

      it { FileEntity.count.should == 1 }

      it {
        @json['file_entity_id'].should == FileEntity.last.id
      }

      it {
        @json['saved_size'].should == 1024
      }

      context '不带 file_entity_id 继续上传' do
        context '参数合法' do
          before {
            post :upload, :file_name  => 'test.zip',
                          :file_size  => 62614734,
                          :start_byte => 1024,
                          :blob       => @blob
            @json1 = JSON::parse(response.body)
          }

          it {
            @json1['saved_size'].should == 2048
          }

          it {
            FileEntity.last.saved_size.should == 2048
          }
        end

        context '参数不合法' do
          before {
            post :upload, :file_name  => 'test.zip',
                          :file_size  => 62614734,
                          :start_byte => 1023,
                          :blob       => @blob

            post :upload, :file_name  => 'test.zip',
                          :file_size  => 62614734,
                          :start_byte => 2987,
                          :blob       => @blob

            @json2 = JSON::parse(response.body)
          }

          it {
            @json2['saved_size'].should == 1024
          }

          it {
            FileEntity.last.saved_size.should == 1024
          }
        end
      end

      context '带着 file_entity_id 继续上传' do
        context 'file_entity_id 有效' do
          context '参数合法' do
            before {
              post :upload, :file_entity_id => FileEntity.last.id,
                            :file_name      => 'test.zip',
                            :file_size      => 62614734,
                            :start_byte     => 0,
                            :blob           => @blob
              @json3 = JSON::parse(response.body)
            }

            it {
              @json3['saved_size'].should == 1024
            }
          end

          context '参数不合法' do
            before {
              post :upload, :file_entity_id => FileEntity.last.id,
                            :file_name  => 'test.zip',
                            :file_size  => 62614734,
                            :start_byte => 1023,
                            :blob       => @blob

              post :upload, :file_entity_id => FileEntity.last.id,
                            :file_name  => 'test.zip',
                            :file_size  => 62614734,
                            :start_byte => 2987,
                            :blob       => @blob

              @json4 = JSON::parse(response.body)
            }

            it {
              @json4['saved_size'].should == 1024
            }

            it {
              FileEntity.last.saved_size.should == 1024
            }
          end
        end

        context 'file_entity_id 无效' do
          before {
            @last_id = FileEntity.last.id
            post :upload, :file_entity_id => -2,
                          :file_name      => 'test.zip',
                          :file_size      => 62614734,
                          :start_byte     => 0,
                          :blob           => @blob
            @json5 = JSON::parse(response.body)
          }

          it {
            @json5['saved_size'].should == 1024
          }

          it {
            @json5['file_entity_id'].should == @last_id
          }
        end
      end
    end
  end

  describe 'POST #upload 不允许上传空文件' do
    before {
      sign_in(FactoryGirl.create(:user))
      blob = ActionDispatch::Http::UploadedFile.new({
        :filename => 'blob',
        :type => 'text/html',
        :tempfile => File.new(Rails.root.join('spec/data/upload_test_files/empty.txt')) # 这是一个空文件
      })

      post :upload, :file_name  => 'test.zip',
                    :file_size  => 0,
                    :start_byte => 0,
                    :blob       => blob
    }

    it {
      response.code.should == '415'
    }

    it {
      response.body.should == 'cannot upload a empty file.'
    }
  end


  describe 'POST #upload_clipboard 不允许上传空文件' do
    before do
      sign_in(FactoryGirl.create(:user))
      post :upload_clipboard, :file => nil
    end

    it{
      response.code.should == "415"
    }

    it{
      response.body.should == 'cannot upload a empty file.'
    }
  end

  describe 'POST #upload_clipboard 上传文件' do
    before do
      sign_in(FactoryGirl.create(:user))
      @file = File.new(Rails.root.join("spec/data/file_entity.jpg"))
    end
    
    it{
      expect {
        file_entity = FileEntity.new(:attach => @file)
        file_entity.save
      }.to change {
        FileEntity.all.count
      }.by(1)
    }
  end
end