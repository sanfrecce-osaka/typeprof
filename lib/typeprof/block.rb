module TypeProf
  class Block
    include Utils::StructuralEquality
  end

  class ISeqBlock < Block
    def initialize(iseq, ep)
      @iseq = iseq
      @outer_ep = ep
    end

    attr_reader :iseq, :outer_ep

    def inspect
      "#<ISeqBlock: #{ @outer_ep.source_location }>"
    end

    def consistent?(other)
      if other.is_a?(ISeqBlock)
        self == other
      else
        true # XXX
      end
    end

    def substitute(_subst, _depth)
      self
    end

    def do_call(aargs, caller_ep, caller_env, scratch, replace_recv_ty:, &ctn)
      blk_env = scratch.return_envs[@outer_ep]
      blk_env = blk_env.replace_recv_ty(replace_recv_ty) if replace_recv_ty
      aargs = scratch.globalize_type(aargs, caller_env, caller_ep)

      scratch.add_block_signature!(self, aargs.to_block_signature)

      locals = [Type.nil] * @iseq.locals.size

      blk_ty, start_pcs = aargs.setup_formal_arguments(:block, locals, @iseq.fargs_format)
      if blk_ty.is_a?(String)
        scratch.error(caller_ep, blk_ty)
        ctn[Type.any, caller_ep, caller_env]
        return
      end

      nctx = Context.new(@iseq, @outer_ep.ctx.cref, nil)
      callee_ep = ExecutionPoint.new(nctx, 0, @outer_ep)
      nenv = Env.new(blk_env.static_env, locals, [], nil)
      alloc_site = AllocationSite.new(callee_ep)
      locals.each_with_index do |ty, i|
        alloc_site2 = alloc_site.add_id(i)
        nenv, ty = scratch.localize_type(ty, nenv, callee_ep, alloc_site2)
        nenv = nenv.local_update(i, ty)
      end

      start_pcs.each do |start_pc|
        scratch.merge_env(ExecutionPoint.new(nctx, start_pc, @outer_ep), nenv)
      end

      scratch.add_block_to_ctx!(self, callee_ep.ctx)
      scratch.add_callsite!(callee_ep.ctx, caller_ep, caller_env, &ctn)
    end
  end

  class TypedBlock < Block
    def initialize(msig, ret_ty)
      @msig = msig
      @ret_ty = ret_ty
    end

    attr_reader :msig, :ret_ty

    def consistent?(other)
      if other.is_a?(ISeqBlock)
        raise "assert false"
      else
        self == other
      end
    end

    def substitute(subst, depth)
      msig = @msig.substitute(subst, depth)
      ret_ty = @ret_ty.substitute(subst, depth)
      TypedBlock.new(msig, ret_ty)
    end

    def do_call(aargs, caller_ep, caller_env, scratch, replace_recv_ty:, &ctn)
      aargs = scratch.globalize_type(aargs, caller_env, caller_ep)
      subst = aargs.consistent_with_method_signature?(@msig)
      unless subst
        scratch.warn(caller_ep, "The arguments is not compatibile to RBS block")
      end
      # check?
      #subst = { Type::Var.new(:self) => caller_env.static_env.recv_ty }
      # XXX: Update type vars
      ctn[@ret_ty, caller_ep, caller_env]
    end
  end

  class SymbolBlock < Block
    def initialize(sym)
      @sym = sym
    end

    attr_reader :iseq, :outer_ep

    def inspect
      "#<SymbolBlock: #{ @sym }>"
    end

    def consistent?(other)
      true # XXX
    end

    def substitute(_subst, _depth)
      self
    end

    def do_call(aargs, caller_ep, caller_env, scratch, replace_recv_ty:, &ctn)
      if aargs.lead_tys.size >= 1
        recv = aargs.lead_tys[0]
        aargs = ActualArguments.new(aargs.lead_tys[1..], aargs.rest_ty, aargs.kw_tys, aargs.blk_ty)
      elsif aargs.rest_ty
        recv = aargs.rest_ty.elems.squash_or_any # XXX: need to shift
      else
        raise
      end

      scratch.add_block_signature!(self, aargs.to_block_signature)

      recv.each_child do |recv|
        scratch.do_send(recv, @sym, aargs, caller_ep, caller_env, &ctn)
      end
    end
  end
end
