// automatically generated by the FlatBuffers compiler, do not modify

/**
 * @const
 * @namespace
 */
var Chat = Chat || {};

/**
 * @constructor
 */
Chat.Response = function() {
  /**
   * @type {flatbuffers.ByteBuffer}
   */
  this.bb = null;

  /**
   * @type {number}
   */
  this.bb_pos = 0;
};

/**
 * @param {number} i
 * @param {flatbuffers.ByteBuffer} bb
 * @returns {Chat.Response}
 */
Chat.Response.prototype.__init = function(i, bb) {
  this.bb_pos = i;
  this.bb = bb;
  return this;
};

/**
 * @param {flatbuffers.ByteBuffer} bb
 * @param {Chat.Response=} obj
 * @returns {Chat.Response}
 */
Chat.Response.getRootAsResponse = function(bb, obj) {
  return (obj || new Chat.Response).__init(bb.readInt32(bb.position()) + bb.position(), bb);
};

/**
 * @param {flatbuffers.Builder} builder
 */
Chat.Response.startResponse = function(builder) {
  builder.startObject(0);
};

/**
 * @param {flatbuffers.Builder} builder
 * @returns {flatbuffers.Offset}
 */
Chat.Response.endResponse = function(builder) {
  var offset = builder.endObject();
  return offset;
};

/**
 * @constructor
 */
Chat.Meta = function() {
  /**
   * @type {flatbuffers.ByteBuffer}
   */
  this.bb = null;

  /**
   * @type {number}
   */
  this.bb_pos = 0;
};

/**
 * @param {number} i
 * @param {flatbuffers.ByteBuffer} bb
 * @returns {Chat.Meta}
 */
Chat.Meta.prototype.__init = function(i, bb) {
  this.bb_pos = i;
  this.bb = bb;
  return this;
};

/**
 * @param {flatbuffers.ByteBuffer} bb
 * @param {Chat.Meta=} obj
 * @returns {Chat.Meta}
 */
Chat.Meta.getRootAsMeta = function(bb, obj) {
  return (obj || new Chat.Meta).__init(bb.readInt32(bb.position()) + bb.position(), bb);
};

/**
 * @returns {number}
 */
Chat.Meta.prototype.onlineAt = function() {
  var offset = this.bb.__offset(this.bb_pos, 4);
  return offset ? this.bb.readUint32(this.bb_pos + offset) : 0;
};

/**
 * @param {flatbuffers.Encoding=} optionalEncoding
 * @returns {string|Uint8Array|null}
 */
Chat.Meta.prototype.phxRef = function(optionalEncoding) {
  var offset = this.bb.__offset(this.bb_pos, 6);
  return offset ? this.bb.__string(this.bb_pos + offset, optionalEncoding) : null;
};

/**
 * @param {flatbuffers.Builder} builder
 */
Chat.Meta.startMeta = function(builder) {
  builder.startObject(2);
};

/**
 * @param {flatbuffers.Builder} builder
 * @param {number} onlineAt
 */
Chat.Meta.addOnlineAt = function(builder, onlineAt) {
  builder.addFieldInt32(0, onlineAt, 0);
};

/**
 * @param {flatbuffers.Builder} builder
 * @param {flatbuffers.Offset} phxRefOffset
 */
Chat.Meta.addPhxRef = function(builder, phxRefOffset) {
  builder.addFieldOffset(1, phxRefOffset, 0);
};

/**
 * @param {flatbuffers.Builder} builder
 * @returns {flatbuffers.Offset}
 */
Chat.Meta.endMeta = function(builder) {
  var offset = builder.endObject();
  return offset;
};

/**
 * @constructor
 */
Chat.Metas = function() {
  /**
   * @type {flatbuffers.ByteBuffer}
   */
  this.bb = null;

  /**
   * @type {number}
   */
  this.bb_pos = 0;
};

/**
 * @param {number} i
 * @param {flatbuffers.ByteBuffer} bb
 * @returns {Chat.Metas}
 */
Chat.Metas.prototype.__init = function(i, bb) {
  this.bb_pos = i;
  this.bb = bb;
  return this;
};

/**
 * @param {flatbuffers.ByteBuffer} bb
 * @param {Chat.Metas=} obj
 * @returns {Chat.Metas}
 */
Chat.Metas.getRootAsMetas = function(bb, obj) {
  return (obj || new Chat.Metas).__init(bb.readInt32(bb.position()) + bb.position(), bb);
};

/**
 * @param {flatbuffers.Encoding=} optionalEncoding
 * @returns {string|Uint8Array|null}
 */
Chat.Metas.prototype.user = function(optionalEncoding) {
  var offset = this.bb.__offset(this.bb_pos, 4);
  return offset ? this.bb.__string(this.bb_pos + offset, optionalEncoding) : null;
};

/**
 * @param {number} index
 * @param {Chat.Meta=} obj
 * @returns {Chat.Meta}
 */
Chat.Metas.prototype.metas = function(index, obj) {
  var offset = this.bb.__offset(this.bb_pos, 6);
  return offset ? (obj || new Chat.Meta).__init(this.bb.__indirect(this.bb.__vector(this.bb_pos + offset) + index * 4), this.bb) : null;
};

/**
 * @returns {number}
 */
Chat.Metas.prototype.metasLength = function() {
  var offset = this.bb.__offset(this.bb_pos, 6);
  return offset ? this.bb.__vector_len(this.bb_pos + offset) : 0;
};

/**
 * @param {flatbuffers.Builder} builder
 */
Chat.Metas.startMetas = function(builder) {
  builder.startObject(2);
};

/**
 * @param {flatbuffers.Builder} builder
 * @param {flatbuffers.Offset} userOffset
 */
Chat.Metas.addUser = function(builder, userOffset) {
  builder.addFieldOffset(0, userOffset, 0);
};

/**
 * @param {flatbuffers.Builder} builder
 * @param {flatbuffers.Offset} metasOffset
 */
Chat.Metas.addMetas = function(builder, metasOffset) {
  builder.addFieldOffset(1, metasOffset, 0);
};

/**
 * @param {flatbuffers.Builder} builder
 * @param {Array.<flatbuffers.Offset>} data
 * @returns {flatbuffers.Offset}
 */
Chat.Metas.createMetasVector = function(builder, data) {
  builder.startVector(4, data.length, 4);
  for (var i = data.length - 1; i >= 0; i--) {
    builder.addOffset(data[i]);
  }
  return builder.endVector();
};

/**
 * @param {flatbuffers.Builder} builder
 * @param {number} numElems
 */
Chat.Metas.startMetasVector = function(builder, numElems) {
  builder.startVector(4, numElems, 4);
};

/**
 * @param {flatbuffers.Builder} builder
 * @returns {flatbuffers.Offset}
 */
Chat.Metas.endMetas = function(builder) {
  var offset = builder.endObject();
  return offset;
};

/**
 * @constructor
 */
Chat.Payload = function() {
  /**
   * @type {flatbuffers.ByteBuffer}
   */
  this.bb = null;

  /**
   * @type {number}
   */
  this.bb_pos = 0;
};

/**
 * @param {number} i
 * @param {flatbuffers.ByteBuffer} bb
 * @returns {Chat.Payload}
 */
Chat.Payload.prototype.__init = function(i, bb) {
  this.bb_pos = i;
  this.bb = bb;
  return this;
};

/**
 * @param {flatbuffers.ByteBuffer} bb
 * @param {Chat.Payload=} obj
 * @returns {Chat.Payload}
 */
Chat.Payload.getRootAsPayload = function(bb, obj) {
  return (obj || new Chat.Payload).__init(bb.readInt32(bb.position()) + bb.position(), bb);
};

/**
 * @param {flatbuffers.Encoding=} optionalEncoding
 * @returns {string|Uint8Array|null}
 */
Chat.Payload.prototype.body = function(optionalEncoding) {
  var offset = this.bb.__offset(this.bb_pos, 4);
  return offset ? this.bb.__string(this.bb_pos + offset, optionalEncoding) : null;
};

/**
 * @param {flatbuffers.Encoding=} optionalEncoding
 * @returns {string|Uint8Array|null}
 */
Chat.Payload.prototype.receiver = function(optionalEncoding) {
  var offset = this.bb.__offset(this.bb_pos, 6);
  return offset ? this.bb.__string(this.bb_pos + offset, optionalEncoding) : null;
};

/**
 * @param {flatbuffers.Encoding=} optionalEncoding
 * @returns {string|Uint8Array|null}
 */
Chat.Payload.prototype.sender = function(optionalEncoding) {
  var offset = this.bb.__offset(this.bb_pos, 8);
  return offset ? this.bb.__string(this.bb_pos + offset, optionalEncoding) : null;
};

/**
 * @returns {number}
 */
Chat.Payload.prototype.timestamp = function() {
  var offset = this.bb.__offset(this.bb_pos, 10);
  return offset ? this.bb.readUint32(this.bb_pos + offset) : 0;
};

/**
 * @param {Chat.Response=} obj
 * @returns {Chat.Response|null}
 */
Chat.Payload.prototype.response = function(obj) {
  var offset = this.bb.__offset(this.bb_pos, 12);
  return offset ? (obj || new Chat.Response).__init(this.bb.__indirect(this.bb_pos + offset), this.bb) : null;
};

/**
 * @param {flatbuffers.Encoding=} optionalEncoding
 * @returns {string|Uint8Array|null}
 */
Chat.Payload.prototype.status = function(optionalEncoding) {
  var offset = this.bb.__offset(this.bb_pos, 14);
  return offset ? this.bb.__string(this.bb_pos + offset, optionalEncoding) : null;
};

/**
 * @param {number} index
 * @param {Chat.Metas=} obj
 * @returns {Chat.Metas}
 */
Chat.Payload.prototype.joins = function(index, obj) {
  var offset = this.bb.__offset(this.bb_pos, 16);
  return offset ? (obj || new Chat.Metas).__init(this.bb.__indirect(this.bb.__vector(this.bb_pos + offset) + index * 4), this.bb) : null;
};

/**
 * @returns {number}
 */
Chat.Payload.prototype.joinsLength = function() {
  var offset = this.bb.__offset(this.bb_pos, 16);
  return offset ? this.bb.__vector_len(this.bb_pos + offset) : 0;
};

/**
 * @param {number} index
 * @param {Chat.Metas=} obj
 * @returns {Chat.Metas}
 */
Chat.Payload.prototype.leaves = function(index, obj) {
  var offset = this.bb.__offset(this.bb_pos, 18);
  return offset ? (obj || new Chat.Metas).__init(this.bb.__indirect(this.bb.__vector(this.bb_pos + offset) + index * 4), this.bb) : null;
};

/**
 * @returns {number}
 */
Chat.Payload.prototype.leavesLength = function() {
  var offset = this.bb.__offset(this.bb_pos, 18);
  return offset ? this.bb.__vector_len(this.bb_pos + offset) : 0;
};

/**
 * @param {number} index
 * @param {Chat.Metas=} obj
 * @returns {Chat.Metas}
 */
Chat.Payload.prototype.state = function(index, obj) {
  var offset = this.bb.__offset(this.bb_pos, 20);
  return offset ? (obj || new Chat.Metas).__init(this.bb.__indirect(this.bb.__vector(this.bb_pos + offset) + index * 4), this.bb) : null;
};

/**
 * @returns {number}
 */
Chat.Payload.prototype.stateLength = function() {
  var offset = this.bb.__offset(this.bb_pos, 20);
  return offset ? this.bb.__vector_len(this.bb_pos + offset) : 0;
};

/**
 * @param {flatbuffers.Builder} builder
 */
Chat.Payload.startPayload = function(builder) {
  builder.startObject(9);
};

/**
 * @param {flatbuffers.Builder} builder
 * @param {flatbuffers.Offset} bodyOffset
 */
Chat.Payload.addBody = function(builder, bodyOffset) {
  builder.addFieldOffset(0, bodyOffset, 0);
};

/**
 * @param {flatbuffers.Builder} builder
 * @param {flatbuffers.Offset} receiverOffset
 */
Chat.Payload.addReceiver = function(builder, receiverOffset) {
  builder.addFieldOffset(1, receiverOffset, 0);
};

/**
 * @param {flatbuffers.Builder} builder
 * @param {flatbuffers.Offset} senderOffset
 */
Chat.Payload.addSender = function(builder, senderOffset) {
  builder.addFieldOffset(2, senderOffset, 0);
};

/**
 * @param {flatbuffers.Builder} builder
 * @param {number} timestamp
 */
Chat.Payload.addTimestamp = function(builder, timestamp) {
  builder.addFieldInt32(3, timestamp, 0);
};

/**
 * @param {flatbuffers.Builder} builder
 * @param {flatbuffers.Offset} responseOffset
 */
Chat.Payload.addResponse = function(builder, responseOffset) {
  builder.addFieldOffset(4, responseOffset, 0);
};

/**
 * @param {flatbuffers.Builder} builder
 * @param {flatbuffers.Offset} statusOffset
 */
Chat.Payload.addStatus = function(builder, statusOffset) {
  builder.addFieldOffset(5, statusOffset, 0);
};

/**
 * @param {flatbuffers.Builder} builder
 * @param {flatbuffers.Offset} joinsOffset
 */
Chat.Payload.addJoins = function(builder, joinsOffset) {
  builder.addFieldOffset(6, joinsOffset, 0);
};

/**
 * @param {flatbuffers.Builder} builder
 * @param {Array.<flatbuffers.Offset>} data
 * @returns {flatbuffers.Offset}
 */
Chat.Payload.createJoinsVector = function(builder, data) {
  builder.startVector(4, data.length, 4);
  for (var i = data.length - 1; i >= 0; i--) {
    builder.addOffset(data[i]);
  }
  return builder.endVector();
};

/**
 * @param {flatbuffers.Builder} builder
 * @param {number} numElems
 */
Chat.Payload.startJoinsVector = function(builder, numElems) {
  builder.startVector(4, numElems, 4);
};

/**
 * @param {flatbuffers.Builder} builder
 * @param {flatbuffers.Offset} leavesOffset
 */
Chat.Payload.addLeaves = function(builder, leavesOffset) {
  builder.addFieldOffset(7, leavesOffset, 0);
};

/**
 * @param {flatbuffers.Builder} builder
 * @param {Array.<flatbuffers.Offset>} data
 * @returns {flatbuffers.Offset}
 */
Chat.Payload.createLeavesVector = function(builder, data) {
  builder.startVector(4, data.length, 4);
  for (var i = data.length - 1; i >= 0; i--) {
    builder.addOffset(data[i]);
  }
  return builder.endVector();
};

/**
 * @param {flatbuffers.Builder} builder
 * @param {number} numElems
 */
Chat.Payload.startLeavesVector = function(builder, numElems) {
  builder.startVector(4, numElems, 4);
};

/**
 * @param {flatbuffers.Builder} builder
 * @param {flatbuffers.Offset} stateOffset
 */
Chat.Payload.addState = function(builder, stateOffset) {
  builder.addFieldOffset(8, stateOffset, 0);
};

/**
 * @param {flatbuffers.Builder} builder
 * @param {Array.<flatbuffers.Offset>} data
 * @returns {flatbuffers.Offset}
 */
Chat.Payload.createStateVector = function(builder, data) {
  builder.startVector(4, data.length, 4);
  for (var i = data.length - 1; i >= 0; i--) {
    builder.addOffset(data[i]);
  }
  return builder.endVector();
};

/**
 * @param {flatbuffers.Builder} builder
 * @param {number} numElems
 */
Chat.Payload.startStateVector = function(builder, numElems) {
  builder.startVector(4, numElems, 4);
};

/**
 * @param {flatbuffers.Builder} builder
 * @returns {flatbuffers.Offset}
 */
Chat.Payload.endPayload = function(builder) {
  var offset = builder.endObject();
  return offset;
};

/**
 * @constructor
 */
Chat.Message = function() {
  /**
   * @type {flatbuffers.ByteBuffer}
   */
  this.bb = null;

  /**
   * @type {number}
   */
  this.bb_pos = 0;
};

/**
 * @param {number} i
 * @param {flatbuffers.ByteBuffer} bb
 * @returns {Chat.Message}
 */
Chat.Message.prototype.__init = function(i, bb) {
  this.bb_pos = i;
  this.bb = bb;
  return this;
};

/**
 * @param {flatbuffers.ByteBuffer} bb
 * @param {Chat.Message=} obj
 * @returns {Chat.Message}
 */
Chat.Message.getRootAsMessage = function(bb, obj) {
  return (obj || new Chat.Message).__init(bb.readInt32(bb.position()) + bb.position(), bb);
};

/**
 * @param {flatbuffers.ByteBuffer} bb
 * @returns {boolean}
 */
Chat.Message.bufferHasIdentifier = function(bb) {
  return bb.__has_identifier('CHAT');
};

/**
 * @param {flatbuffers.Encoding=} optionalEncoding
 * @returns {string|Uint8Array|null}
 */
Chat.Message.prototype.ref = function(optionalEncoding) {
  var offset = this.bb.__offset(this.bb_pos, 4);
  return offset ? this.bb.__string(this.bb_pos + offset, optionalEncoding) : null;
};

/**
 * @param {flatbuffers.Encoding=} optionalEncoding
 * @returns {string|Uint8Array|null}
 */
Chat.Message.prototype.joinRef = function(optionalEncoding) {
  var offset = this.bb.__offset(this.bb_pos, 6);
  return offset ? this.bb.__string(this.bb_pos + offset, optionalEncoding) : null;
};

/**
 * @param {flatbuffers.Encoding=} optionalEncoding
 * @returns {string|Uint8Array|null}
 */
Chat.Message.prototype.topic = function(optionalEncoding) {
  var offset = this.bb.__offset(this.bb_pos, 8);
  return offset ? this.bb.__string(this.bb_pos + offset, optionalEncoding) : null;
};

/**
 * @param {flatbuffers.Encoding=} optionalEncoding
 * @returns {string|Uint8Array|null}
 */
Chat.Message.prototype.event = function(optionalEncoding) {
  var offset = this.bb.__offset(this.bb_pos, 10);
  return offset ? this.bb.__string(this.bb_pos + offset, optionalEncoding) : null;
};

/**
 * @param {Chat.Payload=} obj
 * @returns {Chat.Payload|null}
 */
Chat.Message.prototype.payload = function(obj) {
  var offset = this.bb.__offset(this.bb_pos, 12);
  return offset ? (obj || new Chat.Payload).__init(this.bb.__indirect(this.bb_pos + offset), this.bb) : null;
};

/**
 * @param {flatbuffers.Encoding=} optionalEncoding
 * @returns {string|Uint8Array|null}
 */
Chat.Message.prototype.status = function(optionalEncoding) {
  var offset = this.bb.__offset(this.bb_pos, 14);
  return offset ? this.bb.__string(this.bb_pos + offset, optionalEncoding) : null;
};

/**
 * @param {flatbuffers.Builder} builder
 */
Chat.Message.startMessage = function(builder) {
  builder.startObject(6);
};

/**
 * @param {flatbuffers.Builder} builder
 * @param {flatbuffers.Offset} refOffset
 */
Chat.Message.addRef = function(builder, refOffset) {
  builder.addFieldOffset(0, refOffset, 0);
};

/**
 * @param {flatbuffers.Builder} builder
 * @param {flatbuffers.Offset} joinRefOffset
 */
Chat.Message.addJoinRef = function(builder, joinRefOffset) {
  builder.addFieldOffset(1, joinRefOffset, 0);
};

/**
 * @param {flatbuffers.Builder} builder
 * @param {flatbuffers.Offset} topicOffset
 */
Chat.Message.addTopic = function(builder, topicOffset) {
  builder.addFieldOffset(2, topicOffset, 0);
};

/**
 * @param {flatbuffers.Builder} builder
 * @param {flatbuffers.Offset} eventOffset
 */
Chat.Message.addEvent = function(builder, eventOffset) {
  builder.addFieldOffset(3, eventOffset, 0);
};

/**
 * @param {flatbuffers.Builder} builder
 * @param {flatbuffers.Offset} payloadOffset
 */
Chat.Message.addPayload = function(builder, payloadOffset) {
  builder.addFieldOffset(4, payloadOffset, 0);
};

/**
 * @param {flatbuffers.Builder} builder
 * @param {flatbuffers.Offset} statusOffset
 */
Chat.Message.addStatus = function(builder, statusOffset) {
  builder.addFieldOffset(5, statusOffset, 0);
};

/**
 * @param {flatbuffers.Builder} builder
 * @returns {flatbuffers.Offset}
 */
Chat.Message.endMessage = function(builder) {
  var offset = builder.endObject();
  return offset;
};

/**
 * @param {flatbuffers.Builder} builder
 * @param {flatbuffers.Offset} offset
 */
Chat.Message.finishMessageBuffer = function(builder, offset) {
  builder.finish(offset, 'CHAT');
};

// Exports for Node.js and RequireJS
this.Chat = Chat;