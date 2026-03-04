matproxy.Add({
    name = "PlayerColor", 
    init = function( self, mat, values )
        -- Store the name of the variable we want to set
        self.ResultTo = values.resultvar
    end, 
    bind = function( self, mat, ent ) 
        if ( not IsValid(ent) ) then
            mat:SetVector( self.ResultTo, vector_origin )
            return
        end

        -- If the target ent has a function called GetPlayerColor then use that
        -- The function SHOULD return a Vector with the chosen player's colour.

        -- In sandbox this function is created as a network function, 
        -- in player_sandbox.lua in SetupDataTables
		if ( ent.GetPlayerColor ) then
			local clr = ent:GetPlayerColor()
            mat:SetVector( self.ResultTo, isvector(clr) and clr or vector_origin )
            return
        end

        local owner = ent.GetOwner and ent:GetOwner() or nil
        if (
            IsValid(owner) and
            owner.GetPlayerColor and
            (owner:GetNWEntity("RagdollEntity") == ent or ent.RagdollEntity == ent)
        ) then
			local clr = owner:GetPlayerColor()
			mat:SetVector( self.ResultTo, isvector(clr) and clr or vector_origin )
            return
		end

        mat:SetVector( self.ResultTo, vector_origin )
   end 
})
