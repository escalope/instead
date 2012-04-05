-- stead.phrase_prefix = '--'

local function isReaction(ph)
	return ph.ans ~= nil or ph.code ~= nil
end

local function phr_get(self)
	local n = #self.__phr_stack;
	if n == 0 then return 1 end
	return self.__phr_stack[n];
end

local function phr_pop(self)
	local n = #self.__phr_stack;
	if n <= 1 then return false end
	stead.table.remove(here().__phr_stack, n)
	return true
end

function dialog_look(self)
	local i,n,v,ph,ii
	n = 1
	local start = phr_get(self)
	for i,ph,ii in opairs(self.obj) do
		if ii >= start then
			ph = stead.ref(ph);
			if not ph.dsc then
				break
			end
			if isPhrase(ph) and not isDisabled(ph) then
				if isReaction(ph) then
					local a
					if stead.phrase_prefix then
						a = stead.cat(stead.phrase_prefix, ph:look())
					else
						a = txtnm(n, ph:look())
					end
					v = stead.par('^', v, a);
					n = n + 1
				else
					v = stead.par('^', v, stead.call(ph, 'dsc'))
				end
			end
		end
	end
	return v;
end

function dialog_rescan(self, from)
	local i,k,ph,ii, start
	k = 1
	local start
	if type(from) == 'number' then
		start = from
	else
		start = phr_get(self)
	end
	for i,ph,ii in opairs(self.obj) do
		if ii >= start then
			ph = stead.ref(ph);
			if not ph.dsc then
				break
			end
			if isPhrase(ph) and not isDisabled(ph) and isReaction(ph) then
				ph.nam = tostring(k);
				k = k + 1;
			end
		end
	end
	if k == 1 then
		return false
	end
	return true
end

function dialog_enter(self)
	if not dialog_rescan(self) then
		return nil, false
	end
	self.__last_answer = false
	return nil, true
end

function dialog_current(self,...)
	return phr_get(self)
end

function dialog_empty(self, from)
	return not dialog_rescan(self, from);
end

function dialog_pjump(self, w)
	local ph, i = dialog_phrase(self, w)
	if not ph then
		return false
	end
	if not dialog_rescan(self, i) then
		return false
	end
	local n = #self.__phr_stack;
	if n == 0 then
		stead.table.insert(self.__phr_stack, i);
	else
		self.__phr_stack[n] = i
	end
	return true
end

function pjump(w)
	if not isDialog(here()) then
		return false
	end
	return here():pjump(w)
end

function dialog_pstart(self, w)
	if not w then 
		w = 1 
	end
	local ph, i = dialog_phrase(self, w)
	if not ph then
		return
	end
	self.__phr_stack = { i }
	return
end

function pstart(w)
	if not isDialog(here()) then
		return
	end
	here():pstart(w)
end

function dialog_psub(self, w)
	local ph, i = dialog_phrase(self, w)
	if not ph then
		return false
	end
	if not dialog_rescan(self, i) then
		return false
	end
	stead.table.insert(self.__phr_stack, i);
	return
end

function psub(w)
	if not isDialog(here()) then
		return false
	end
	return here():psub(w)
end

function dialog_pret(self)
	while true do
		if  not phr_pop(self) then
			break
		end
		if dialog_rescan(self) then
			break
		end
	end
	return
end

function pret()
	if not isDialog(here()) then
		return
	end
	return here():pret()
end

function phr(ask, answ, act)
	local i = 1
	local r = {}
	local dis = false
	
	if type(ask) ~= 'table' then -- old style
		local p = phrase ( { dsc = ask, ans = answ, code = act });
		return p
	end

	local v = ask

	if type(v[i]) == 'boolean' then
		i = i + 1
		dis = not v[i]
	end
	r.dsc = v[i]
	i = i + 1
	r.ans = v[i]
	i = i + 1
	r.code = v[i]
	r.always = v.always
	r.key = v.key
	r = phrase(r)
	if dis then
		r = r:disable()
	end
	return r;
end

function _phr(ask, answ, act) -- compat only?
	local p = phr(ask, answ, act);
	p:disable()
	return p
end

stead.phr = phr

function phrase_save(self, name, h, need)
	if need then
		local m = " = phrase {"
		local post = '}\n'
		if isDisabled(self) then
			post = "}:disable()\n"
		end
		m = stead.string.format("%s%s", name, m);
		if self.dsc then
			m = m..stead.string.format("dsc = %s, ", stead.tostring(self.dsc));
		end

		if self.ans then
			m = m..stead.string.format("ans = %s, ", stead.tostring(self.ans));
		end

		if self.code then
			m = m..stead.string.format("code = %s, ", stead.tostring(self.code));
		end

		if self.key then
			m = m..stead.string.format("key = %s, ", stead.tostring(self.key));
		end

		if self.always then
			m = m..stead.string.format("always = %s, ", stead.tostring(self.always));
		end
		h:write(m..post);
	end
	stead.savemembers(h, self, name, false);
end

local function dialog_phr2obj(self)
	local k, v, n, q, a

	if type(self.phr) ~= 'table' then
		return
	end

	n = 0

	for k,v in ipairs(self.phr) do
		if type(v) == 'table' then
			local nn = {}

			while type(v[1]) == 'number' do
				stead.table.insert(nn, v[1])
				stead.table.remove(v, 1)
			end

			stead.table.sort(nn);

			local p = stead.phr(v)
			if #nn == 0 then
				n = n + 1
				stead.table.insert(nn, n)
			else
				n = nn[#nn] -- maximum index
			end

			for q, a in ipairs(nn) do
				if self.obj[a] then
					error ("Error in phr structure (numbering).", 4);
				end
				self.obj[a] = p
			end
		else
			error ("Error in phr structure (wrong item).", 4);
		end
	end
end

function dialog_phrase(self, num)
	if not num then
		return
	end
	if not tonumber(num) then
		local k,v,i
		for k,v,i in opairs(self.obj) do
			v = stead.ref(v)
			if isPhrase(v) and v.key == num then
				return v, i
			end
		end
		return nil
	end
	num = tonumber(num)
	return stead.ref(self.obj[num]), num;
end

function dialog_last(self, v)
	local r = self.__last_answer
	if v ~= nil then
		self.__last_answer = v
	end
	return r
end

function phrase_action(self)
	local ph = self;
	local r, ret;

	if isDisabled(ph) then
		return nil, false
	end
-- here it is
	if not ph.always then
		ph:disable(); -- /* disable it!!! */
	end

	local last = stead.call(ph, 'ans');

	here().__last_answer = last;
	
	if type(ph.code) == 'string' then
		local f = stead.eval(ph.code);
		if f ~= nil then
			ret = f();
		else
			error ("Error while eval phrase action.");
		end
	elseif type(ph.code) == 'function' then
		ret = ph.code(self);
	end

	if ret == nil then ret = stead.pget(); end

	if last == true or ret == true then
		r = true;
	end

	while isDialog(here()) and not dialog_rescan(here()) and phr_pop(here())  do -- do returns

	end

	local wh = here();

	while isDialog(wh) and not dialog_rescan(wh) and stead.from(wh) ~= wh do
		wh = stead.from(wh)
	end

	if wh ~= here() then
		ret = stead.par(stead.scene_delim, ret, stead.back(wh));
	end
	
	ret = stead.par(stead.scene_delim, last, ret);

	here().__last_answer = ret;

	if ret == nil then
		return r -- hack?
	end
	return ret
end

dlg = stead.hook(dlg, 
function(f, v, ...)
	if v.current == nil then
		v.current = dialog_current
	end
	if v.last == nil then
		v.last = dialog_last
	end
	if v.pstart == nil then
		v.pstart = dialog_pstart
	end
	if v.pjump == nil then
		v.pjump = dialog_pjump
	end
	if v.pret == nil then
		v.pret = dialog_pret
	end
	if v.psub == nil then
		v.psub = dialog_psub
	end
	v = f(v, ...)
	v.__last_answer = false
	v.__phr_stack = { 1 }
	dialog_phr2obj(v);
	return v
end)
