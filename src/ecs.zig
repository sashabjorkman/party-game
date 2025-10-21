const std = @import("std");

/// Entity identifier, with generation tracker.
pub const Entity = packed struct(u64) {
    pub const tombstone: Entity = .{
        .identifier = ~0,
        .generation = ~0,
    };

    identifier: u32 = 0,
    generation: u32 = 0,

    pub inline fn toBits(self: Entity) u64 {
        return @bitCast(self);
    }

    pub inline fn fromBits(bits: u64) Entity {
        return @bitCast(bits);
    }

    pub inline fn eq(self: Entity, other: Entity) bool {
        return self.toBits() == other.toBits();
    }

    pub inline fn ne(self: Entity, other: Entity) bool {
        return self.toBits() != other.toBits();
    }

    pub inline fn isTombstone(self: Entity) bool {
        return self.identifier == tombstone.identifier;
    }
};

/// Stores world metadata. All components must be default initializable.
pub const Registry = struct {
    entities: usize,
    components: []const type,
};

pub const WorldError = error{
    spawn_limit_exceeded,
    dead_entity_killed,
    dead_entity_promoted,
    dead_entity_demoted,
    dead_entity_inspected,
    entity_repromoted,
    entity_redemoted,
    entity_lacking_component_inspected,
};

/// Stores and manipulates entities and their corresponding components.
pub fn World(comptime registry: Registry) type {
    for (registry.components) |C| {
        if (@typeInfo(C) != .@"struct") {
            @compileError("Expected struct component, found non-struct " ++ @typeName(C));
        }
    }

    const Entities = std.bit_set.ArrayBitSet(u64, registry.entities);
    const Signature = std.bit_set.IntegerBitSet(registry.components.len);

    // TODO: fit all data exactly.
    const buffer_size = blk: {
        var size = 0;
        for (registry.components) |C| {
            size += registry.entities * @sizeOf(C) + @alignOf(C);
        }
        break :blk size;
    };

    const buffer_alignment = if (registry.components.len > 0) @alignOf(registry.components[0]) else 0;

    const component_sizes = blk: {
        var sizes: [registry.components.len]usize = undefined;

        for (registry.components, 0..) |C, i| {
            sizes[i] = @sizeOf(C);
        }

        break :blk sizes;
    };

    const component_alignments = blk: {
        var alignments: [registry.components.len]usize = undefined;

        for (registry.components, 0..) |C, i| {
            alignments[i] = @alignOf(C);
        }

        break :blk alignments;
    };

    // Maps component identifiers to their corresponding buffer index.
    const component_handles = blk: {
        var components: [registry.components.len]usize = undefined;
        var cursor: usize = 0;

        for (&components, component_sizes, component_alignments) |*component, size, alignment| {
            const remainder = cursor % alignment;

            if (remainder != 0) {
                cursor += alignment - remainder;
            }

            component.* = cursor;
            cursor = cursor + registry.entities * size;
        }

        break :blk components;
    };

    return struct {
        const SelfWorld = @This();

        pub const empty = SelfWorld{};

        comptime registry: Registry = registry,
        entities: Entities = Entities.initEmpty(),
        generations: [registry.entities]u32 = .{0} ** registry.entities,
        signatures: [registry.entities]Signature = .{Signature.initEmpty()} ** registry.entities,
        buffer: [buffer_size]u8 align(buffer_alignment) = undefined,

        /// Removes all entities from the world.
        pub fn reset(self: *SelfWorld) void {
            self.entities = Entities.initEmpty();
            self.generations = .{0} ** registry.entities;
            self.signatures = .{Signature.initEmpty()} ** registry.entities;
            self.buffer = undefined;
        }

        /// Creates a new entity with components inferred from passed values.
        pub fn initEntity(self: *SelfWorld, components: anytype) !Entity {
            const Type: type = @TypeOf(components);
            const info = @typeInfo(Type);

            if (info != .@"struct") {
                @compileError("Expected tuple or struct argument, found " ++ @typeName(Type));
            }

            comptime var component_types: []const type = &.{};
            const fields = info.@"struct".fields;

            inline for (fields) |field| {
                const component = @field(components, field.name);
                const Component: type = @TypeOf(component);
                component_types = component_types ++ .{Component};
            }

            const identifier = self.entities.complement().findFirstSet() orelse {
                return WorldError.spawn_limit_exceeded;
            };

            const entity = Entity{
                .identifier = @intCast(identifier),
                .generation = self.generations[identifier],
            };

            const signature = comptime getComponentSignature(component_types);

            self.entities.set(identifier);

            inline for (fields) |field| {
                const component = @field(components, field.name);
                const Component: type = @TypeOf(component);

                self.getComponentArray(Component)[identifier] = component;
            }

            self.signatures[identifier].setUnion(signature);

            return entity;
        }

        /// Removes an entity.
        pub fn deinitEntity(self: *SelfWorld, entity: Entity) !void {
            if (!self.isEntityAlive(entity)) {
                return WorldError.dead_entity_killed;
            }

            self.entities.unset(entity.identifier);
            self.generations[entity.identifier] +%= 1;
            self.signatures[entity.identifier].mask = 0;
        }

        /// Adds components to an entity. Components should be passed as a struct.
        pub fn addEntityComponents(self: *SelfWorld, entity: Entity, components: anytype) !void {
            const Type: type = @TypeOf(components);
            const info = @typeInfo(Type);

            if (info != .@"struct") {
                @compileError("Expected tuple or struct argument, found " ++ @typeName(Type));
            }

            comptime var component_types: []const type = &.{};
            const fields = info.@"struct".fields;

            inline for (fields) |field| {
                const component = @field(components, field.name);
                const Component: type = @TypeOf(component);
                component_types = component_types ++ .{Component};
            }

            if (!self.isEntityAlive(entity)) {
                return WorldError.dead_entity_promoted;
            }

            const signature = comptime getComponentSignature(component_types);

            if (self.signatures[entity.identifier].intersectWith(signature).mask != 0) {
                return WorldError.entity_repromoted;
            }

            inline for (fields) |field| {
                const component = @field(components, field.name);
                const Component: type = @TypeOf(component);

                self.getComponentArray(Component)[entity.identifier] = component;
            }

            self.signatures[entity.identifier].setUnion(signature);
        }

        /// Removes components from an entity.
        pub fn removeEntityComponents(self: *SelfWorld, entity: Entity, comptime components: []const type) !void {
            const signature = comptime getComponentSignature(components);

            if (!self.isEntityAlive(entity)) {
                return WorldError.dead_entity_demoted;
            }

            if (self.signatures[entity.identifier].complement().intersectWith(signature).mask != 0) {
                return WorldError.entity_redemoted;
            }

            self.signatures[entity.identifier].setIntersection(signature.complement());
        }

        /// Inspects a component from an entity. Prefer using `query()`.
        pub fn getEntityComponent(self: *SelfWorld, entity: Entity, comptime C: type) !*C {
            if (!isEntityAlive(self, entity)) {
                return WorldError.dead_entity_inspected;
            }

            if (self.signatures[entity.identifier].intersectWith(comptime getComponentTag(C)).mask == 0) {
                return WorldError.entity_lacking_component_inspected;
            }

            return &self.getComponentArray(C)[entity.identifier];
        }

        /// Returns true if entity currently exists.
        pub fn isEntityAlive(self: *const SelfWorld, entity: Entity) bool {
            if (!self.entities.isSet(entity.identifier)) {
                return false;
            }

            return entity.generation == self.generations[entity.identifier];
        }

        /// Returns true if an entity exists and matches component signature.
        pub fn isEntitySignature(self: *const SelfWorld, entity: Entity, comptime include: []const type, comptime exclude: []const type) bool {
            if (!self.entities.isSet(entity.identifier)) {
                return false;
            }

            const included = comptime getComponentSignature(include);
            const excluded = comptime getComponentSignature(exclude);
            const signature = self.signatures[entity.identifier];

            return signature.intersectWith(included).xorWith(signature.intersectWith(excluded)).eql(included);
        }

        /// Retrieves all entities matching component signature.
        /// Spawning, killing, promoting, and demoting entities may invalidate queries.
        pub fn query(self: *SelfWorld, comptime include: []const type, comptime exclude: []const type) Query(include, exclude) {
            return .init(self);
        }

        fn getComponentArray(self: *SelfWorld, comptime Component: type) *[registry.entities]Component {
            const identifier = comptime getComponentIdentifier(Component);
            const handle = comptime component_handles[identifier];
            const ptr: *anyopaque = self.buffer[handle..];

            return @ptrCast(@alignCast(ptr));
        }

        fn getComponentIdentifier(comptime Component: type) usize {
            comptime {
                for (registry.components, 0..) |C, i| {
                    if (C == Component) {
                        return i;
                    }
                }

                @compileError("Attempted to retrieve identifier of invalid component: " ++ @typeName(Component));
            }
        }

        fn getComponentTag(comptime Component: type) Signature {
            comptime {
                for (registry.components, 0..) |C, i| {
                    if (C == Component) {
                        var mask = Signature.initEmpty();
                        mask.set(i);
                        return mask;
                    }
                }

                @compileError("Attempted to retrieve tag of invalid component: " ++ @typeName(Component));
            }
        }

        fn getComponentSignature(comptime components: []const type) Signature {
            comptime {
                var mask = Signature.initEmpty();

                for (components) |c| {
                    mask.setUnion(getComponentTag(c));
                }

                return mask;
            }
        }

        /// An iterator over entities with a specific component signature.
        /// Included components refers to components that the entity must have.
        /// Excluded components refers to components that the entity must not have.
        fn Query(comptime include: []const type, comptime exclude: []const type) type {
            comptime {
                for (include) |I| {
                    for (exclude) |E| {
                        if (I == E) {
                            @compileError("Query both includes and excludes " ++ @typeName(I));
                        }
                    }
                }
            }

            return struct {
                const SelfQuery = @This();
                const QueryWorld = *SelfWorld;

                /// Wraps an entity in the query context, improving safety and performance.
                const QueriedEntity = struct {
                    entity: Entity,
                };

                world: QueryWorld,
                iterator: Entities.Iterator(.{}),

                fn init(world: QueryWorld) SelfQuery {
                    return SelfQuery{
                        .world = world,
                        .iterator = world.entities.iterator(.{}),
                    };
                }

                /// Retrieves the next entity.
                pub fn next(self: *SelfQuery) ?QueriedEntity {
                    const included = comptime getComponentSignature(include);
                    const excluded = comptime getComponentSignature(exclude);

                    while (self.iterator.next()) |i| {
                        const signature: Signature = self.world.signatures[i];

                        if (signature.intersectWith(included).xorWith(signature.intersectWith(excluded)).eql(included)) {
                            const entity = Entity{
                                .identifier = @intCast(i),
                                .generation = self.world.generations[i],
                            };

                            return QueriedEntity{ .entity = entity };
                        }
                    }

                    return null;
                }

                /// Retrieves component data of a queried entity.
                pub fn getEntityComponent(self: *const SelfQuery, entity: QueriedEntity, comptime C: type) *C {
                    comptime {
                        for (include) |c| {
                            if (c == C) {
                                break;
                            }
                        } else {
                            @compileError("Attempted to retrieve non-queried component: " ++ @typeName(C));
                        }
                    }

                    return &self.world.getComponentArray(C)[entity.entity.identifier];
                }
            };
        }
    };
}
