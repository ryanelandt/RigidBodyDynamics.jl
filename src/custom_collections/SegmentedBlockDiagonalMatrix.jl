const AbstractMatrixBlock{T, M} = SubArray{T,2,M,Tuple{UnitRange{Int},UnitRange{Int}},false}

"""
$(TYPEDEF)

`SegmentedBlockDiagonalMatrix` is an `AbstractMatrix` backed by a parent `AbstractMatrix`, which
additionally stores a sequence of views into the diagonal blocks of the parent matrix. This
type is useful for storing and updating block-diagonal matrices whose block contents
may change but whose overall structure is fixed, such as configuration derivative <-> velocity
jacobians.
"""
struct SegmentedBlockDiagonalMatrix{T, M<:AbstractMatrix{T}} <: AbstractMatrix{T}
    parent::M
    blocks::Vector{AbstractMatrixBlock{T, M}}

    function SegmentedBlockDiagonalMatrix{T, M}(parent::M, block_indices) where {T, M<:AbstractMatrix{T}}
        check_contiguous_block_ranges(parent, block_indices)
        blocks = collect(view(parent, indices...) for indices in block_indices)
        new{T, M}(parent, blocks)
    end
end

SegmentedBlockDiagonalMatrix(parent::M, block_indices) where {T, M<:AbstractMatrix{T}} = SegmentedBlockDiagonalMatrix{T, M}(parent, block_indices)

function SegmentedBlockDiagonalMatrix{T}(initializer, rows::Integer, cols::Integer, block_indices) where T
    parent = Matrix{T}(initializer, rows, cols)
    SegmentedBlockDiagonalMatrix{T}(parent, block_indices)
end

Base.parent(m::SegmentedBlockDiagonalMatrix) = m.parent
Base.size(m::SegmentedBlockDiagonalMatrix) = size(m.parent)
@propagate_inbounds Base.getindex(v::SegmentedBlockDiagonalMatrix, i::Int) = v.parent[i]
@propagate_inbounds Base.setindex!(v::SegmentedBlockDiagonalMatrix, value, i::Int) = v.parent[i] = value
Base.IndexStyle(::Type{<:SegmentedBlockDiagonalMatrix}) = IndexLinear()
blocks(m::SegmentedBlockDiagonalMatrix) = m.blocks

function check_contiguous_block_ranges(parent::AbstractMatrix, block_indices)
    if !_is_contiguous_and_diagonal(parent, block_indices)
        throw(ArgumentError("The `block_indices` should be a vector of index ranges corresponding to non-overlapping contiguous diagonal blocks"))
    end
end

function _is_contiguous_and_diagonal(parent::AbstractMatrix, block_indices)
    expected_starts = first.(axes(parent))
    for inds in block_indices
        if first.(inds) !== expected_starts
            return false
        end
        expected_starts = last.(inds) .+ 1
    end
    if expected_starts !== last.(axes(parent)) .+ 1
        return false
    end
    return true
end
