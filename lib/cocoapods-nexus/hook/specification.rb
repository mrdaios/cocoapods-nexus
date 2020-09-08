require 'cocoapods-core'

module Pod
  class Specification
    class << Specification
      def _eval_nexus_podspec(nexus_podspec, parent_podspec)
        podspec_string = nexus_podspec.gsub('Pod::Spec.new', 'Pod::Spec.nexus(parent_podspec)')
                                      .gsub('Pod::Specification.new', 'Pod::Spec.nexus(parent_podspec)')
        # rubocop:disable Eval
        eval(podspec_string, binding)
        # rubocop:enable Eval
      end

      def nexus(parent_podspec)
        yield parent_podspec if block_given?
      end
    end
  end
end
