module Travis
  module Requests
    module Services
      class Requeue < Travis::Services::Base
        extend Travis::Instrumentation

        register :requeue_request

        def run
          requeue if request && accept?
        end
        instrument :run

        def accept?
          push_permission? && requeueable?
        end

        def messages
          messages = []
          messages << { :notice => 'The build was successfully requeued.' } if accept?
          messages << { :error  => 'You do not seem to have push permissions.' } unless push_permission?
          messages << { :error  => 'This build currently can not be requeued.' } unless requeueable?
          messages
        end

        private

          def requeue
            request.start!
            true
          end

          def push_permission?
            args = [:repository_id => request.repository_id]
            args.unshift([Travis.config.roles.requeue_request]) if Travis.config.roles.requeue_request
            current_user.permission?(*args)
          end

          def requeueable?
            defined?(@requeueable) ? @requeueable : @requeueable = request.requeueable?
          end

          def data
            { :event_type => request.event_type, :payload => request.payload, :token => params[:token] }
          end

          def request
            build && build.request
          end

          def build
            @build ||= service(:find_build, :id => params[:build_id]).run
          end

          class Instrument < Notification::Instrument
            def run_completed
              publish(
                :msg => "build_id=#{target.params[:build_id]} #{result ? 'accepted' : 'not accepted'}",
                :build_id => target.params[:build_id],
                :accept? => target.accept?
              )
            end
          end
          Instrument.attach_to(self)
      end
    end
  end
end