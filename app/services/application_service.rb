# Base class for service objects that expose a single command-style entry point.
#
# Subclasses implement an instance-level `#call`; callers normally use the
# class-level `.call` convenience wrapper.
class ApplicationService
  # Instantiate and execute a service object.
  #
  # @return [Object] the value returned by the subclass instance `#call`
  def self.call(...)
    new(...).call
  end
end
