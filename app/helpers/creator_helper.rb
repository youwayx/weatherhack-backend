	require 'json'
module CreatorHelper

	def getAllDistances(addresses)
		num = addresses.length
		dists = Array.new(num)
		api_key = "AIzaSyC8ia0RzrNk9ygYbJwbRO3nQ8KOu1RxfRY"
		base_url = "https://maps.googleapis.com/maps/api/directions/json?"	
		(0..num-1).each do |i|
			(i..num-1).each do |j|
				if (i!=j)
					if (dists[i]==nil)
						dists[i] = Array.new(num)
					end
					if (dists[j]==nil)
						dists[j]=Array.new(num)
					end
					response = HTTParty.get(base_url+"origin="+ addresses[i].gsub(" ","%20") + "&destination=" + addresses[j].gsub(" ","%20") + "&key="+api_key)
					json_data = JSON.parse(response.body.to_s)
					
					time = json_data["routes"][0]
					if (time!=nil)
						time = time["legs"][0]
					end
					if (time!=nil)
						time = time["duration"]["text"]
						time = parseTime(time)
					end

					dists[i][j]=time
					dists[j][i]=time
				end
			end
		end
		return dists
	end
	def parseTime(time)
		array = time.split(" ")
		if (array.length==2)
			array[0].to_i
		elsif (array.length==4)
			array[0].to_i*60+array[2].to_i
		end
	end
	def addTime(start, added)
		newtime = start+added
		if (newtime %100>=60)
			newtime+=100
			newtime-=60
		end
		return newtime
	end

	def getTime(tags)
		tags.each do |t|
			if (t=="aquarium")
				return 430
			elsif(t=="museum")
				return 330
			elsif (t=="art_gallery")
				return 230
			elsif (t=="shopping_mall")
				return 300
			elsif (t=="movie_theater")
				return 200
			elsif (t=="church")
				return 100
			elsif (t=="establishment")
				return 100
			else
				return 150
			end
		end
	end

	def getOperatingTimes(place_id,dayNum)
		api_key = "AIzaSyC8ia0RzrNk9ygYbJwbRO3nQ8KOu1RxfRY"
		base_url = "https://maps.googleapis.com/maps/api/place/details/json?"
		response = HTTParty.get(base_url+"placeid="+place_id+"&key="+api_key)
		json_data = JSON.parse(response.body.to_s)
		result = json_data["result"]
		if (result!=nil)
			opening_hours = result["opening_hours"]
			if (opening_hours!=nil && opening_hours.length>0)
				periods = opening_hours["periods"]
				open = periods[dayNum]["open"]["time"]
				close = periods[dayNum]["close"]["time"]
			else
				open = 0;
				close = 0;
			end
			times = [open, close]
		else
			times = [0,0]
		end
		
		return times
	end

	
	def getSchedules(all_schedules,distances,latArray,lngArray, prev_index,place_names, place_ids,place_tags, been_to, sofar, precip, start_time, end_time,dayNum)
		flag = true;
		(0..place_ids.length-1).each do |i|
			if (been_to[i]==false)
				the_tags = place_tags[i].split("|")
				time_spent = getTime(the_tags)
				operating_times = getOperatingTimes(place_ids[i],dayNum)
				open_time=operating_times[0].to_i
				close_time = operating_times[1].to_i

				# puts "close_time "+close_time.to_s
				# puts "tot_time "+addTime(start_time,time_spent).to_s
				travel_time=0
				if (prev_index!=-1)
					travel_time = distances[i][prev_index]
				end
				if (travel_time==nil)
					travel_time=0
				end
				if (start_time<=open_time)

					possible_new_time =addTime(open_time,travel_time+time_spent)

				else
					possible_new_time =addTime(start_time,travel_time+time_spent)
				end
				if ((open_time==0 &&close_time==0 &&precip<0.5) || (close_time>=possible_new_time && possible_new_time<=end_time))
					flag = false;
					new_sofar = Array.new
					sofar.each do |a|
						new_sofar.push(a)
					end
					if (travel_time!=0)
						json_travel = JSON[{"travel" => {"time" => travel_time.to_s, "origin" =>[latArray[prev_index], longArray[prev_index]],
							"destination" => [latArray[i], longArray[i]]}}.to_json] 
						new_sofar.push(json_travel)
					end
					new_start_time =  possible_new_time

					new_been_to = Array.new(place_names.length)
					(0..new_been_to.length-1).each do |n|
						new_been_to[n]=been_to[n]
					end
					new_been_to[i]=true
					
					pre_json = JSON[{"visit" => {"name" => place_names[i], "place_id" => place_ids[i], :duration => time_spent.to_s, :curTime => new_start_time.to_s} }.to_json]
					
					new_sofar.push(pre_json)
					getSchedules(all_schedules,distances,latArray,lngArray, i,place_names,place_ids,place_tags,new_been_to,new_sofar,precip,new_start_time,end_time,dayNum)


				end

			end
		end
		if (flag)
			all_schedules.push(JSON[sofar.to_json])
			if (all_schedules.length>=12)
				return 
			end
		end

	end
end
