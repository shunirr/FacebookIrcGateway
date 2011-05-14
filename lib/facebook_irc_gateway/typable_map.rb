
# https://github.com/cho45/net-irc/blob/master/examples/tig.rb

module FacebookIrcGateway
	class TypableMap < Hash
		Roman = %w[
			  a   i   u   e   o  ka  ki  ku  ke  ko  sa shi  su  se  so
			 ta chi tsu  te  to  na  ni  nu  ne  no  ha  hi  fu  he  ho
			 ma  mi  mu  me  mo  ya      yu      yo  ra  ri  ru  re  ro
			 wa              wo   n
			 ga  gi  gu  ge  go  za  ji  zu  ze  zo  da          de  do
			 ba  bi  bu  be  bo  pa  pi  pu  pe  po
		].freeze

		def initialize(size = nil, shuffle = false)
			if shuffle
				@seq = Roman.dup
				if @seq.respond_to?(:shuffle!)
					@seq.shuffle!
				else
					@seq = Array.new(@seq.size) { @seq.delete_at(rand(@seq.size)) }
				end
				@seq.freeze
			else
				@seq = Roman
			end
			@n    = 0
			@size = size || @seq.size
		end

		def generate(n)
			ret = []
			begin
				n, r = n.divmod(@seq.size)
				ret << @seq[r]
			end while n > 0
			ret.reverse.join
		end

		def push(obj)
			id = generate(@n)
			self[id] = obj
			@n += 1
			@n %= @size
			id
		end
		alias :<< :push

		def clear
			@n = 0
			super
		end

		def first
			@size.times do |i|
				id = generate((@n + i) % @size)
				return self[id] if key? id
			end unless empty?
			nil
		end

		def last
			@size.times do |i|
				id = generate((@n - 1 - i) % @size)
				return self[id] if key? id
			end unless empty?
			nil
		end

		private :[]=
	end
end

