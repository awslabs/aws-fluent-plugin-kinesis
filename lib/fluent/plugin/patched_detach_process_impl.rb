#
#  Copyright 2014-2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
#  Licensed under the Amazon Software License (the "License").
#  You may not use this file except in compliance with the License.
#  A copy of the License is located at
#
#  http://aws.amazon.com/asl/
#
#  or in the "license" file accompanying this file. This file is distributed
#  on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
#  express or implied. See the License for the specific language governing
#  permissions and limitations under the License.

module Fluent
  module PatchedDetachProcessImpl
    def on_detach_process(i)
    end

    def on_exit_process(i)
    end

    private

    def detach_process_impl(num, &block)
      children = []

      num.times do |i|
        pid, forward_thread = DetachProcessManager.instance.fork(self)

        if pid
          # parent process
          $log.info "detached process", :class=>self.class, :pid=>pid
          children << [pid, forward_thread]
          next
        end

        # child process
        begin
          on_detach_process(i)

          block.call

          # disable Engine.stop called by signal handler
          Engine.define_singleton_method(:stop) do
            # do nothing
          end
          # override signal handlers called by parent process
          fin = ::Fluent::DetachProcessImpl::FinishWait.new
          trap :INT do
            fin.stop
          end
          trap :TERM do
            fin.stop
          end
          #forward_thread.join  # TODO this thread won't stop because parent doesn't close pipe
          fin.wait

          on_exit_process(i)
          exit! 0
        ensure
          $log.error "unknown error while shutting down this child process", :error=>$!.to_s, :pid=>Process.pid
          $log.error_backtrace
        end

        exit! 1
      end

      # parent process
      # override shutdown method to kill child processes
      define_singleton_method(:shutdown) do
        children.each {|pair|
          begin
            pid = pair[0]
            forward_thread = pair[1]
            if pid
              Process.kill(:TERM, pid)
              forward_thread.join   # wait until child closes pipe
              Process.waitpid(pid)
              pair[0] = nil
            end
          rescue
            $log.error "unknown error while shutting down remote child process", :error=>$!.to_s
            $log.error_backtrace
          end
        }
      end

      # override target.emit and write event stream to the pipe
      forwarders = children.map {|pair| pair[1].forwarder }
      if forwarders.length > 1
        # use roundrobin
        fwd = DetachProcessManager::MultiForwarder.new(forwarders)
      else
        fwd = forwarders[0]
      end
      define_singleton_method(:emit) do |tag,es,chain|
        chain.next
        fwd.emit(tag, es)
      end
    end
  end
end
