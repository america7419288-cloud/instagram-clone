// server/src/controllers/community.controller.js

const {
  Community,
  CommunityChannel,
  CommunityMember,
  CommunityRule,
  CommunityJoinRequest,
  CommunityPost,
  User,
  sequelize,
} = require('../models');
const {
  successResponse,
  errorResponse,
  paginatedResponse,
} = require('../utils/response.utils');
const { emitToUser, getIO } = require('../services/socket.service');
const { Op } = require('sequelize');
const {
  uploadImageToCloudinary,
  uploadVideoToCloudinary,
  getMediaType,
} = require('../services/upload.service');

// ─── HELPER: Format community post response ──────────────────
const formatCommunityPost = (post) => {
  const p = post.toJSON ? post.toJSON() : post;
  return {
    id: p.id,
    community_id: p.community_id,
    channel_id: p.channel_id,
    author_id: p.author_id,
    content: p.content,
    media_urls: p.media_urls || [],
    type: p.type,
    poll: p.poll || null,
    event: p.event || null,
    likes: p.likes || [],
    comment_count: p.comment_count || 0,
    like_count: p.like_count || 0,
    is_pinned: p.is_pinned || false,
    is_announcement: p.is_announcement || false,
    status: p.status,
    author: p.author ? {
      id: p.author.id,
      username: p.author.username,
      profile_pic_url: p.author.profile_pic_url,
    } : null,
    created_at: p.created_at || p.createdAt,
  };
};

// ─── 1. CREATE COMMUNITY ─────────────────────────────────────
const createCommunity = async (req, res) => {
  const transaction = await sequelize.transaction();
  try {
    const { name, handle, description, category, privacy, tags } = req.body;
    const userId = req.user.id;

    if (!name || name.trim().length === 0) {
      return errorResponse(res, 400, 'Community name is required.');
    }

    if (!handle || !/^[a-zA-Z0-9_]{3,30}$/.test(handle)) {
      return errorResponse(res, 400, 'Handle must be 3-30 characters and contain only letters, numbers, or underscores.');
    }

    // Check uniqueness
    const existing = await Community.findOne({
      where: {
        [Op.or]: [
          { name: name.trim() },
          { handle: handle.toLowerCase().trim() },
        ],
      },
    });

    if (existing) {
      if (existing.name.toLowerCase() === name.trim().toLowerCase()) {
        return errorResponse(res, 400, 'A community with this name already exists.');
      }
      return errorResponse(res, 400, 'This handle is already taken.');
    }

    // Generate unique invite code
    const inviteCode = require('crypto').randomBytes(8).toString('hex');

    // Create Community
    const community = await Community.create(
      {
        name: name.trim(),
        handle: handle.toLowerCase().trim(),
        description: description?.trim() || '',
        category,
        privacy: privacy || 'public',
        tags: tags || [],
        created_by: userId,
        invite_link: inviteCode,
        member_count: 1,
      },
      { transaction }
    );

    // Add Creator as Owner Member
    await CommunityMember.create(
      {
        community_id: community.id,
        user_id: userId,
        role: 'owner',
      },
      { transaction }
    );

    // Create Default Channels
    await CommunityChannel.bulkCreate([
      {
        community_id: community.id,
        name: 'general',
        description: 'General discussion',
        type: 'general',
        is_default: true,
        order: 0,
      },
      {
        community_id: community.id,
        name: 'announcements',
        description: 'Important updates',
        type: 'announcement',
        is_default: false,
        order: 1,
        allowed_roles: ['admin', 'moderator'],
      },
    ], { transaction });

    await transaction.commit();

    const fullCommunity = await Community.findByPk(community.id, {
      include: [
        { model: User, as: 'creator', attributes: ['id', 'username', 'profile_pic_url'] },
      ],
    });

    return successResponse(res, 201, 'Community created successfully.', { community: fullCommunity });
  } catch (error) {
    await transaction.rollback();
    console.error('❌ Create community error:', error);
    return errorResponse(res, 500, 'Failed to create community.', error.message);
  }
};

// ─── 2. DISCOVER COMMUNITIES ─────────────────────────────────
const discoverCommunities = async (req, res) => {
  try {
    const { category, page = 1, limit = 20 } = req.query;
    const userId = req.user.id;

    // Get communities where the user is NOT already a member or banned
    const joinedMemberships = await CommunityMember.findAll({
      where: { user_id: userId },
      attributes: ['community_id', 'is_banned'],
    });

    const joinedIds = joinedMemberships.map(m => m.community_id);
    const bannedIds = joinedMemberships.filter(m => m.is_banned).map(m => m.community_id);

    const query = {
      id: { [Op.notIn]: joinedIds },
      privacy: 'public',
      is_active: true,
    };

    if (category && category !== 'all') {
      query.category = category;
    }

    const { count, rows: communities } = await Community.findAndCountAll({
      where: query,
      order: [['member_count', 'DESC'], ['created_at', 'DESC']],
      limit: parseInt(limit),
      offset: (parseInt(page) - 1) * parseInt(limit),
      include: [{ model: User, as: 'creator', attributes: ['id', 'username'] }],
    });

    return successResponse(res, 200, 'Communities discovered successfully.', {
      communities,
      total: count,
      page: parseInt(page),
      has_more: count > page * limit,
    });
  } catch (error) {
    console.error('❌ Discover communities error:', error);
    return errorResponse(res, 500, 'Failed to discover communities.', error.message);
  }
};

// ─── 3. SEARCH COMMUNITIES ───────────────────────────────────
const searchCommunities = async (req, res) => {
  try {
    const { q, page = 1, limit = 20 } = req.query;

    if (!q || q.trim().length < 2) {
      return errorResponse(res, 400, 'Search query must be at least 2 characters.');
    }

    const { count, rows: communities } = await Community.findAndCountAll({
      where: {
        privacy: 'public',
        is_active: true,
        [Op.or]: [
          { name: { [Op.iLike]: `%${q.trim()}%` } },
          { handle: { [Op.iLike]: `%${q.trim()}%` } },
          { description: { [Op.iLike]: `%${q.trim()}%` } },
        ],
      },
      order: [['member_count', 'DESC']],
      limit: parseInt(limit),
      offset: (parseInt(page) - 1) * parseInt(limit),
    });

    return successResponse(res, 200, 'Communities searched successfully.', {
      communities,
      total: count,
    });
  } catch (error) {
    console.error('❌ Search communities error:', error);
    return errorResponse(res, 500, 'Failed to search communities.', error.message);
  }
};

// ─── 4. JOIN / LEAVE COMMUNITY ───────────────────────────────
const joinCommunity = async (req, res) => {
  try {
    const { communityId } = req.params;
    const { message } = req.body;
    const userId = req.user.id;

    const community = await Community.findByPk(communityId);
    if (!community) {
      return errorResponse(res, 404, 'Community not found.');
    }

    const member = await CommunityMember.findOne({
      where: { community_id: communityId, user_id: userId },
    });

    if (member) {
      if (member.is_banned) {
        return errorResponse(res, 403, 'You are banned from this community.');
      }
      return errorResponse(res, 400, 'You are already a member of this community.');
    }

    if (community.privacy === 'private') {
      // Create Join Request
      const [request, created] = await CommunityJoinRequest.findOrCreate({
        where: { community_id: communityId, user_id: userId, status: 'pending' },
        defaults: { message: message?.trim() || '' },
      });

      if (!created) {
        return errorResponse(res, 400, 'Your join request is already pending review.');
      }

      // Notify admins via socket
      const admins = await CommunityMember.findAll({
        where: { community_id: communityId, role: { [Op.in]: ['owner', 'admin'] } },
      });

      const io = req.app.get('io');
      if (io) {
        admins.forEach((admin) => {
          emitToUser(io, admin.user_id, 'community-join-request', {
            community_id: communityId,
            user_id: userId,
            username: req.user.username,
          });
        });
      }

      return successResponse(res, 200, 'Join request sent successfully.', { status: 'pending' });
    }

    // Direct Join for Public
    await CommunityMember.create({
      community_id: communityId,
      user_id: userId,
      role: 'member',
    });

    await community.increment('member_count');

    return successResponse(res, 200, 'Joined community successfully.', { status: 'joined' });
  } catch (error) {
    console.error('❌ Join community error:', error);
    return errorResponse(res, 500, 'Failed to join community.', error.message);
  }
};

const leaveCommunity = async (req, res) => {
  try {
    const { communityId } = req.params;
    const userId = req.user.id;

    const community = await Community.findByPk(communityId);
    if (!community) {
      return errorResponse(res, 404, 'Community not found.');
    }

    const member = await CommunityMember.findOne({
      where: { community_id: communityId, user_id: userId },
    });

    if (!member) {
      return errorResponse(res, 404, 'You are not a member of this community.');
    }

    if (member.role === 'owner') {
      return errorResponse(res, 400, 'Owners cannot leave the community without transferring ownership first.');
    }

    await member.destroy();
    await community.decrement('member_count');

    return successResponse(res, 200, 'Left community successfully.');
  } catch (error) {
    console.error('❌ Leave community error:', error);
    return errorResponse(res, 500, 'Failed to leave community.', error.message);
  }
};

// ─── 5. GET COMMUNITY DETAILS ────────────────────────────────
const getCommunity = async (req, res) => {
  try {
    const { communityId } = req.params;
    const userId = req.user.id;

    const community = await Community.findByPk(communityId, {
      include: [
        { model: User, as: 'creator', attributes: ['id', 'username', 'profile_pic_url'] },
      ],
    });

    if (!community || !community.is_active) {
      return errorResponse(res, 404, 'Community not found.');
    }

    const myMembership = await CommunityMember.findOne({
      where: { community_id: communityId, user_id: userId },
    });

    const isMember = !!myMembership && !myMembership.is_banned;
    const role = myMembership ? myMembership.role : null;

    return successResponse(res, 200, 'Community fetched successfully.', {
      community,
      is_member: isMember,
      role,
    });
  } catch (error) {
    console.error('❌ Get community error:', error);
    return errorResponse(res, 500, 'Failed to fetch community details.', error.message);
  }
};

const getMyCommunities = async (req, res) => {
  try {
    const userId = req.user.id;

    const memberships = await CommunityMember.findAll({
      where: { user_id: userId, is_banned: false },
      include: [
        {
          model: Community,
          as: 'community',
          where: { is_active: true },
        },
      ],
      order: [['created_at', 'DESC']],
    });

    const communities = memberships.map(m => m.community);

    return successResponse(res, 200, 'My communities fetched successfully.', { communities });
  } catch (error) {
    console.error('❌ Get my communities error:', error);
    return errorResponse(res, 500, 'Failed to fetch my communities.', error.message);
  }
};

// ─── 6. UPDATE / DELETE COMMUNITY ────────────────────────────
const updateCommunity = async (req, res) => {
  try {
    const { communityId } = req.params;
    const { name, description, category, privacy, settings } = req.body;
    const userId = req.user.id;

    const community = await Community.findByPk(communityId);
    if (!community) {
      return errorResponse(res, 404, 'Community not found.');
    }

    const member = await CommunityMember.findOne({
      where: { community_id: communityId, user_id: userId },
    });

    if (!member || !['owner', 'admin'].includes(member.role)) {
      return errorResponse(res, 403, 'Only admins or the owner can update community details.');
    }

    const updates = {};
    if (name) updates.name = name.trim();
    if (description !== undefined) updates.description = description.trim();
    if (category) updates.category = category;
    if (privacy) updates.privacy = privacy;
    if (settings) updates.settings = { ...community.settings, ...settings };

    await community.update(updates);

    return successResponse(res, 200, 'Community updated successfully.', { community });
  } catch (error) {
    console.error('❌ Update community error:', error);
    return errorResponse(res, 500, 'Failed to update community.', error.message);
  }
};

const deleteCommunity = async (req, res) => {
  try {
    const { communityId } = req.params;
    const userId = req.user.id;

    const community = await Community.findByPk(communityId);
    if (!community) {
      return errorResponse(res, 404, 'Community not found.');
    }

    if (community.created_by !== userId) {
      return errorResponse(res, 403, 'Only the owner can delete the community.');
    }

    await community.update({ is_active: false });

    return successResponse(res, 200, 'Community deleted successfully.');
  } catch (error) {
    console.error('❌ Delete community error:', error);
    return errorResponse(res, 500, 'Failed to delete community.', error.message);
  }
};

// ─── 7. AVATAR / COVER PHOTO UPLOADS ─────────────────────────
const updateAvatar = async (req, res) => {
  try {
    const { communityId } = req.params;
    const userId = req.user.id;

    if (!req.file) {
      return errorResponse(res, 400, 'Avatar image file is required.');
    }

    const community = await Community.findByPk(communityId);
    if (!community) {
      return errorResponse(res, 404, 'Community not found.');
    }

    const member = await CommunityMember.findOne({
      where: { community_id: communityId, user_id: userId },
    });
    if (!member || !['owner', 'admin'].includes(member.role)) {
      return errorResponse(res, 403, 'Only admins or the owner can edit avatar.');
    }

    const uploadResult = await uploadImageToCloudinary(req.file.buffer, req.file.mimetype, 'instagram-clone/communities/avatars');
    const imageUrl = uploadResult.url;
    await community.update({ avatar_url: imageUrl });

    return successResponse(res, 200, 'Community avatar updated successfully.', { avatar_url: imageUrl });
  } catch (error) {
    console.error('❌ Update community avatar error:', error);
    return errorResponse(res, 500, 'Failed to upload avatar.', error.message);
  }
};

const updateCover = async (req, res) => {
  try {
    const { communityId } = req.params;
    const userId = req.user.id;

    if (!req.file) {
      return errorResponse(res, 400, 'Cover image file is required.');
    }

    const community = await Community.findByPk(communityId);
    if (!community) {
      return errorResponse(res, 404, 'Community not found.');
    }

    const member = await CommunityMember.findOne({
      where: { community_id: communityId, user_id: userId },
    });
    if (!member || !['owner', 'admin'].includes(member.role)) {
      return errorResponse(res, 403, 'Only admins or the owner can edit cover image.');
    }

    const uploadResult = await uploadImageToCloudinary(req.file.buffer, req.file.mimetype, 'instagram-clone/communities/covers');
    const imageUrl = uploadResult.url;
    await community.update({ cover_url: imageUrl });

    return successResponse(res, 200, 'Community cover updated successfully.', { cover_url: imageUrl });
  } catch (error) {
    console.error('❌ Update community cover error:', error);
    return errorResponse(res, 500, 'Failed to upload cover.', error.message);
  }
};

// ─── 8. MEMBER MODERATION & ROLES ────────────────────────────
const getMembers = async (req, res) => {
  try {
    const { communityId } = req.params;
    const userId = req.user.id;

    // Check membership and role
    const isMember = await CommunityMember.findOne({
      where: { community_id: communityId, user_id: userId, is_banned: false },
    });
    if (!isMember) {
      return errorResponse(res, 403, 'You must be a member to see the member directory.');
    }

    if (isMember.role === 'member') {
      return errorResponse(res, 403, 'Regular members are not allowed to view the member directory.');
    }

    const members = await CommunityMember.findAll({
      where: { community_id: communityId, is_banned: false },
      include: [{ model: User, as: 'user', attributes: ['id', 'username', 'fullName', 'profile_pic_url'] }],
      order: [['role', 'ASC'], ['created_at', 'ASC']],
    });

    return successResponse(res, 200, 'Members fetched successfully.', { members });
  } catch (error) {
    console.error('❌ Get community members error:', error);
    return errorResponse(res, 500, 'Failed to fetch community members.', error.message);
  }
};

const updateMemberRole = async (req, res) => {
  try {
    const { communityId, userId } = req.params;
    const { role } = req.body; // admin, moderator, member
    const currentUserId = req.user.id;

    if (!['admin', 'moderator', 'member'].includes(role)) {
      return errorResponse(res, 400, 'Invalid role. Use admin, moderator, or member.');
    }

    const community = await Community.findByPk(communityId);
    const updater = await CommunityMember.findOne({
      where: { community_id: communityId, user_id: currentUserId },
    });
    const target = await CommunityMember.findOne({
      where: { community_id: communityId, user_id: userId },
    });

    if (!updater || !['owner', 'admin'].includes(updater.role)) {
      return errorResponse(res, 403, 'Only admins or the owner can change roles.');
    }
    if (!target) {
      return errorResponse(res, 404, 'Target member not found.');
    }

    if (target.role === 'owner') {
      return errorResponse(res, 403, 'Cannot change owner role.');
    }

    await target.update({ role });

    return successResponse(res, 200, `Role successfully changed to ${role}.`);
  } catch (error) {
    console.error('❌ Change role error:', error);
    return errorResponse(res, 500, 'Failed to update role.', error.message);
  }
};

const banMember = async (req, res) => {
  try {
    const { communityId, userId } = req.params;
    const { reason, duration } = req.body;
    const currentUserId = req.user.id;

    const community = await Community.findByPk(communityId);
    const updater = await CommunityMember.findOne({
      where: { community_id: communityId, user_id: currentUserId },
    });
    const target = await CommunityMember.findOne({
      where: { community_id: communityId, user_id: userId },
    });

    if (!updater || !['owner', 'admin', 'moderator'].includes(updater.role)) {
      return errorResponse(res, 403, 'Only moderators or admins can ban members.');
    }

    if (target) {
      if (target.role === 'owner' || target.role === 'admin') {
        return errorResponse(res, 403, 'Cannot ban the owner or admins.');
      }
      
      await target.update({
        is_banned: true,
        banned_reason: reason || 'Banned by moderator',
        banned_until: duration ? new Date(Date.now() + duration * 1000) : null,
      });
      await community.decrement('member_count');
    } else {
      // Create banned shadow record
      await CommunityMember.create({
        community_id: communityId,
        user_id: userId,
        role: 'member',
        is_banned: true,
        banned_reason: reason || 'Banned by moderator',
      });
    }

    return successResponse(res, 200, 'User banned from community successfully.');
  } catch (error) {
    console.error('❌ Ban member error:', error);
    return errorResponse(res, 500, 'Failed to ban user.', error.message);
  }
};

const unbanMember = async (req, res) => {
  try {
    const { communityId, userId } = req.params;
    const currentUserId = req.user.id;

    const updater = await CommunityMember.findOne({
      where: { community_id: communityId, user_id: currentUserId },
    });
    const target = await CommunityMember.findOne({
      where: { community_id: communityId, user_id: userId },
    });

    if (!updater || !['owner', 'admin', 'moderator'].includes(updater.role)) {
      return errorResponse(res, 403, 'Only moderators or admins can unban users.');
    }

    if (target && target.is_banned) {
      await target.destroy(); // Remove banned membership record
      return successResponse(res, 200, 'User successfully unbanned.');
    }

    return errorResponse(res, 404, 'No active ban record found for this user.');
  } catch (error) {
    console.error('❌ Unban member error:', error);
    return errorResponse(res, 500, 'Failed to unban user.', error.message);
  }
};

// ─── 9. JOIN REQUESTS FOR PRIVATE COMMUNITIES ────────────────
const getJoinRequests = async (req, res) => {
  try {
    const { communityId } = req.params;
    const currentUserId = req.user.id;

    const member = await CommunityMember.findOne({
      where: { community_id: communityId, user_id: currentUserId },
    });

    if (!member || !['owner', 'admin'].includes(member.role)) {
      return errorResponse(res, 403, 'Only admins or the owner can manage join requests.');
    }

    const requests = await CommunityJoinRequest.findAll({
      where: { community_id: communityId, status: 'pending' },
      include: [{ model: User, as: 'user', attributes: ['id', 'username', 'fullName', 'profile_pic_url'] }],
      order: [['created_at', 'ASC']],
    });

    return successResponse(res, 200, 'Join requests fetched successfully.', { requests });
  } catch (error) {
    console.error('❌ Get requests error:', error);
    return errorResponse(res, 500, 'Failed to fetch join requests.', error.message);
  }
};

const approveRequest = async (req, res) => {
  const transaction = await sequelize.transaction();
  try {
    const { communityId, userId } = req.params;
    const currentUserId = req.user.id;

    const community = await Community.findByPk(communityId);
    const adminMember = await CommunityMember.findOne({
      where: { community_id: communityId, user_id: currentUserId },
    });

    if (!adminMember || !['owner', 'admin'].includes(adminMember.role)) {
      return errorResponse(res, 403, 'Only admins can approve join requests.');
    }

    const request = await CommunityJoinRequest.findOne({
      where: { community_id: communityId, user_id: userId, status: 'pending' },
    });

    if (!request) {
      return errorResponse(res, 404, 'Pending join request not found.');
    }

    // Update Request
    await request.update({ status: 'approved' }, { transaction });

    // Add to members
    await CommunityMember.create({
      community_id: communityId,
      user_id: userId,
      role: 'member',
    }, { transaction });

    await community.increment('member_count', { transaction });

    await transaction.commit();

    const io = req.app.get('io');
    if (io) {
      emitToUser(io, userId, 'community-request-approved', { community_id: communityId });
    }

    return successResponse(res, 200, 'Join request approved successfully.');
  } catch (error) {
    await transaction.rollback();
    console.error('❌ Approve request error:', error);
    return errorResponse(res, 500, 'Failed to approve request.', error.message);
  }
};

const rejectRequest = async (req, res) => {
  try {
    const { communityId, userId } = req.params;
    const currentUserId = req.user.id;

    const adminMember = await CommunityMember.findOne({
      where: { community_id: communityId, user_id: currentUserId },
    });

    if (!adminMember || !['owner', 'admin'].includes(adminMember.role)) {
      return errorResponse(res, 403, 'Only admins can reject join requests.');
    }

    const request = await CommunityJoinRequest.findOne({
      where: { community_id: communityId, user_id: userId, status: 'pending' },
    });

    if (!request) {
      return errorResponse(res, 404, 'Pending join request not found.');
    }

    await request.update({ status: 'rejected' });

    const io = req.app.get('io');
    if (io) {
      emitToUser(io, userId, 'community-request-rejected', { community_id: communityId });
    }

    return successResponse(res, 200, 'Join request rejected successfully.');
  } catch (error) {
    console.error('❌ Reject request error:', error);
    return errorResponse(res, 500, 'Failed to reject request.', error.message);
  }
};

// ─── 10. CHANNELS LIFE-CYCLE MANAGEMENT ──────────────────────
const getChannels = async (req, res) => {
  try {
    const { communityId } = req.params;
    const userId = req.user.id;

    // Verify membership
    const member = await CommunityMember.findOne({
      where: { community_id: communityId, user_id: userId, is_banned: false },
    });
    if (!member) {
      return errorResponse(res, 403, 'You must be a member to view channels.');
    }

    const channels = await CommunityChannel.findAll({
      where: { community_id: communityId },
      order: [['order', 'ASC']],
    });

    // Filter by allowed roles
    const filtered = channels.filter((ch) => {
      const allowed = ch.allowed_roles || [];
      return allowed.includes(member.role);
    });

    return successResponse(res, 200, 'Channels fetched successfully.', { channels: filtered });
  } catch (error) {
    console.error('❌ Get channels error:', error);
    return errorResponse(res, 500, 'Failed to fetch channels.', error.message);
  }
};

const createChannel = async (req, res) => {
  try {
    const { communityId } = req.params;
    const { name, description, type, allowed_roles } = req.body;
    const userId = req.user.id;

    if (!name || name.trim().length === 0) {
      return errorResponse(res, 400, 'Channel name is required.');
    }

    const member = await CommunityMember.findOne({
      where: { community_id: communityId, user_id: userId },
    });

    if (!member || !['owner', 'admin'].includes(member.role)) {
      return errorResponse(res, 403, 'Only admins or the owner can create channels.');
    }

    const maxOrder = await CommunityChannel.max('order', { where: { community_id: communityId } }) || 0;

    const allowedTypes = ['announcement', 'general', 'media', 'event'];
    let validType = type || 'general';
    if (!allowedTypes.includes(validType)) {
      if (validType === 'text') validType = 'general';
      else validType = 'general';
    }

    const channel = await CommunityChannel.create({
      community_id: communityId,
      name: name.toLowerCase().trim().replace(/\s+/g, '-'),
      description: description?.trim() || '',
      type: validType,
      order: maxOrder + 1,
      allowed_roles: allowed_roles || ['admin', 'moderator', 'member'],
    });

    const io = req.app.get('io');
    if (io) {
      io.to(`community:${communityId}`).emit('channel-created', channel);
    }

    return successResponse(res, 201, 'Channel created successfully.', { channel });
  } catch (error) {
    console.error('❌ Create channel error:', error);
    return errorResponse(res, 500, 'Failed to create channel.', error.message);
  }
};

const updateChannel = async (req, res) => {
  try {
    const { communityId, channelId } = req.params;
    const { name, description, allowed_roles } = req.body;
    const userId = req.user.id;

    const member = await CommunityMember.findOne({
      where: { community_id: communityId, user_id: userId },
    });

    if (!member || !['owner', 'admin'].includes(member.role)) {
      return errorResponse(res, 403, 'Only admins can modify channels.');
    }

    const channel = await CommunityChannel.findOne({
      where: { id: channelId, community_id: communityId },
    });

    if (!channel) {
      return errorResponse(res, 404, 'Channel not found.');
    }

    const updates = {};
    if (name) updates.name = name.toLowerCase().trim().replace(/\s+/g, '-');
    if (description !== undefined) updates.description = description;
    if (allowed_roles) updates.allowed_roles = allowed_roles;

    await channel.update(updates);

    const io = req.app.get('io');
    if (io) {
      io.to(`community:${communityId}`).emit('channel-updated', channel);
    }

    return successResponse(res, 200, 'Channel updated successfully.', { channel });
  } catch (error) {
    console.error('❌ Update channel error:', error);
    return errorResponse(res, 500, 'Failed to update channel.', error.message);
  }
};

const deleteChannel = async (req, res) => {
  try {
    const { communityId, channelId } = req.params;
    const userId = req.user.id;

    const member = await CommunityMember.findOne({
      where: { community_id: communityId, user_id: userId },
    });

    if (!member || !['owner', 'admin'].includes(member.role)) {
      return errorResponse(res, 403, 'Only admins can delete channels.');
    }

    const channel = await CommunityChannel.findOne({
      where: { id: channelId, community_id: communityId },
    });

    if (!channel) {
      return errorResponse(res, 404, 'Channel not found.');
    }

    if (channel.is_default) {
      return errorResponse(res, 400, 'Cannot delete the default general channel.');
    }

    await channel.destroy();

    const io = req.app.get('io');
    if (io) {
      io.to(`community:${communityId}`).emit('channel-deleted', { channel_id: channelId });
    }

    return successResponse(res, 200, 'Channel deleted successfully.');
  } catch (error) {
    console.error('❌ Delete channel error:', error);
    return errorResponse(res, 500, 'Failed to delete channel.', error.message);
  }
};

// ─── 11. POSTS & COMMUNITY FEED ──────────────────────────────
const getCommunityPosts = async (req, res) => {
  try {
    const { communityId } = req.params;
    const { channelId, page = 1, limit = 20 } = req.query;
    const userId = req.user.id;

    const member = await CommunityMember.findOne({
      where: { community_id: communityId, user_id: userId, is_banned: false },
    });

    if (!member) {
      return errorResponse(res, 403, 'You must be a member to access the feed.');
    }

    const query = {
      community_id: communityId,
      status: 'published',
    };

    if (channelId) {
      query.channel_id = channelId;
    }

    const { count, rows: posts } = await CommunityPost.findAndCountAll({
      where: query,
      order: [['is_pinned', 'DESC'], ['created_at', 'DESC']],
      limit: parseInt(limit),
      offset: (parseInt(page) - 1) * parseInt(limit),
      include: [{ model: User, as: 'author', attributes: ['id', 'username', 'profile_pic_url'] }],
    });

    const formatted = posts.map(formatCommunityPost);

    return successResponse(res, 200, 'Feed posts fetched successfully.', {
      posts: formatted,
      total: count,
      page: parseInt(page),
      has_more: count > page * limit,
    });
  } catch (error) {
    console.error('❌ Get feed posts error:', error);
    return errorResponse(res, 500, 'Failed to fetch feed posts.', error.message);
  }
};

const createPost = async (req, res) => {
  try {
    const { communityId } = req.params;
    const { channel_id, content, type, poll, event } = req.body;
    const userId = req.user.id;

    const community = await Community.findByPk(communityId);
    const member = await CommunityMember.findOne({
      where: { community_id: communityId, user_id: userId, is_banned: false },
    });

    if (!member) {
      return errorResponse(res, 403, 'You must be a member to create posts.');
    }

    const channel = await CommunityChannel.findOne({
      where: { id: channel_id, community_id: communityId },
    });

    if (!channel) {
      return errorResponse(res, 404, 'Target channel not found in this community.');
    }

    // Verify write permissions
    if (channel.type === 'announcement' && !['owner', 'admin'].includes(member.role)) {
      return errorResponse(res, 403, 'Only admins can write in the announcements channel.');
    }

    if (community.settings.onlyAdminsCanPost && !['owner', 'admin'].includes(member.role)) {
      return errorResponse(res, 403, 'Writing posts has been restricted to admins only.');
    }

    // Upload Media files if attached
    const mediaUrls = [];
    if (req.files && req.files.length > 0) {
      for (const file of req.files) {
        const mediaType = getMediaType(file.mimetype);
        let uploadResult;
        if (mediaType === 'video') {
          uploadResult = await uploadVideoToCloudinary(file.buffer, file.mimetype, 'instagram-clone/communities/posts/videos');
        } else {
          uploadResult = await uploadImageToCloudinary(file.buffer, file.mimetype, 'instagram-clone/communities/posts');
        }
        mediaUrls.push({ url: uploadResult.url, type: mediaType });
      }
    }

    // Build poll structure
    let parsedPoll = null;
    if (type === 'poll' && poll) {
      const p = typeof poll === 'string' ? JSON.parse(poll) : poll;
      parsedPoll = {
        question: p.question,
        options: p.options.map(text => ({ text, votes: [] })),
        endsAt: p.durationDays ? new Date(Date.now() + p.durationDays * 24 * 60 * 60 * 1000) : null,
      };
    }

    // Build event structure
    let parsedEvent = null;
    if (type === 'event' && event) {
      const ev = typeof event === 'string' ? JSON.parse(event) : event;
      parsedEvent = {
        title: ev.title,
        description: ev.description,
        startDate: ev.startDate,
        endDate: ev.endDate,
        location: ev.location,
        coverUrl: ev.coverUrl || null,
        attendees: [userId], // Author RSVPs by default
      };
    }

    const needsApproval = community.settings.postApprovalRequired && !['owner', 'admin'].includes(member.role);

    const post = await CommunityPost.create({
      community_id: communityId,
      channel_id: channel_id,
      author_id: userId,
      content: content?.trim() || '',
      media_urls: mediaUrls,
      type: type || 'text',
      poll: parsedPoll,
      event: parsedEvent,
      status: needsApproval ? 'pending' : 'published',
    });

    if (needsApproval) {
      return successResponse(res, 200, 'Post submitted successfully. Waiting for moderator approval.', { post });
    }

    // Retrieve and format
    const populated = await CommunityPost.findByPk(post.id, {
      include: [{ model: User, as: 'author', attributes: ['id', 'username', 'profile_pic_url'] }],
    });

    const formatted = formatCommunityPost(populated);

    // Socket broadcast
    const io = req.app.get('io');
    if (io) {
      io.to(`community:${communityId}`).emit('new-community-post', formatted);
    }

    return successResponse(res, 201, 'Post created successfully.', { post: formatted });
  } catch (error) {
    console.error('❌ Create post error:', error);
    return errorResponse(res, 500, 'Failed to create community post.', error.message);
  }
};

const deletePost = async (req, res) => {
  try {
    const { communityId, postId } = req.params;
    const userId = req.user.id;

    const post = await CommunityPost.findOne({ where: { id: postId, community_id: communityId } });
    if (!post) {
      return errorResponse(res, 404, 'Post not found.');
    }

    const member = await CommunityMember.findOne({
      where: { community_id: communityId, user_id: userId },
    });

    const isAuthor = post.author_id === userId;
    const isModerator = member && ['owner', 'admin', 'moderator'].includes(member.role);

    if (!isAuthor && !isModerator) {
      return errorResponse(res, 403, 'You do not have permission to delete this post.');
    }

    await post.destroy();

    const io = req.app.get('io');
    if (io) {
      io.to(`community:${communityId}`).emit('community-post-deleted', { post_id: postId });
    }

    return successResponse(res, 200, 'Post deleted successfully.');
  } catch (error) {
    console.error('❌ Delete post error:', error);
    return errorResponse(res, 500, 'Failed to delete post.', error.message);
  }
};

const likePost = async (req, res) => {
  try {
    const { communityId, postId } = req.params;
    const userId = req.user.id;

    const post = await CommunityPost.findOne({ where: { id: postId, community_id: communityId } });
    if (!post) {
      return errorResponse(res, 404, 'Post not found.');
    }

    const likesArray = [...(post.likes || [])];
    const index = likesArray.indexOf(userId);

    let isLiked = false;
    if (index === -1) {
      likesArray.push(userId);
      isLiked = true;
    } else {
      likesArray.splice(index, 1);
    }

    await post.update({
      likes: likesArray,
      like_count: likesArray.length,
    });

    const io = req.app.get('io');
    if (io) {
      io.to(`community:${communityId}`).emit('community-post-liked', {
        post_id: postId,
        likes: likesArray,
        like_count: likesArray.length,
      });
    }

    return successResponse(res, 200, isLiked ? 'Post liked successfully.' : 'Post unliked successfully.', {
      likes: likesArray,
      like_count: likesArray.length,
    });
  } catch (error) {
    console.error('❌ Like post error:', error);
    return errorResponse(res, 500, 'Failed to toggle like.', error.message);
  }
};

const pinPost = async (req, res) => {
  try {
    const { communityId, postId } = req.params;
    const userId = req.user.id;

    const member = await CommunityMember.findOne({
      where: { community_id: communityId, user_id: userId },
    });

    if (!member || !['owner', 'admin', 'moderator'].includes(member.role)) {
      return errorResponse(res, 403, 'Only moderators or admins can pin posts.');
    }

    const post = await CommunityPost.findOne({ where: { id: postId, community_id: communityId } });
    if (!post) {
      return errorResponse(res, 404, 'Post not found.');
    }

    await post.update({ is_pinned: !post.is_pinned });

    const io = req.app.get('io');
    if (io) {
      io.to(`community:${communityId}`).emit('community-post-pinned', {
        post_id: postId,
        is_pinned: post.is_pinned,
      });
    }

    return successResponse(res, 200, post.is_pinned ? 'Post pinned successfully.' : 'Post unpinned successfully.', {
      is_pinned: post.is_pinned,
    });
  } catch (error) {
    console.error('❌ Pin post error:', error);
    return errorResponse(res, 500, 'Failed to pin/unpin post.', error.message);
  }
};

// ─── 12. RULES & GUIDELINES MANAGEMENT ────────────────────────
const getRules = async (req, res) => {
  try {
    const { communityId } = req.params;

    const rules = await CommunityRule.findAll({
      where: { community_id: communityId },
      order: [['order', 'ASC']],
    });

    return successResponse(res, 200, 'Rules fetched successfully.', { rules });
  } catch (error) {
    console.error('❌ Get rules error:', error);
    return errorResponse(res, 500, 'Failed to fetch rules.', error.message);
  }
};

const addRule = async (req, res) => {
  try {
    const { communityId } = req.params;
    const { title, description } = req.body;
    const userId = req.user.id;

    const member = await CommunityMember.findOne({
      where: { community_id: communityId, user_id: userId },
    });
    if (!member || !['owner', 'admin'].includes(member.role)) {
      return errorResponse(res, 403, 'Only admins can add rules.');
    }

    const maxOrder = await CommunityRule.max('order', { where: { community_id: communityId } }) || 0;

    const rule = await CommunityRule.create({
      community_id: communityId,
      title: title.trim(),
      description: description?.trim() || '',
      order: maxOrder + 1,
    });

    return successResponse(res, 201, 'Rule created successfully.', { rule });
  } catch (error) {
    console.error('❌ Add rule error:', error);
    return errorResponse(res, 500, 'Failed to add rule.', error.message);
  }
};

const updateRule = async (req, res) => {
  try {
    const { communityId, ruleId } = req.params;
    const { title, description, order } = req.body;
    const userId = req.user.id;

    const member = await CommunityMember.findOne({
      where: { community_id: communityId, user_id: userId },
    });
    if (!member || !['owner', 'admin'].includes(member.role)) {
      return errorResponse(res, 403, 'Only admins can modify rules.');
    }

    const rule = await CommunityRule.findOne({ where: { id: ruleId, community_id: communityId } });
    if (!rule) {
      return errorResponse(res, 404, 'Rule not found.');
    }

    const updates = {};
    if (title) updates.title = title.trim();
    if (description !== undefined) updates.description = description.trim();
    if (order !== undefined) updates.order = parseInt(order);

    await rule.update(updates);

    return successResponse(res, 200, 'Rule updated successfully.', { rule });
  } catch (error) {
    console.error('❌ Update rule error:', error);
    return errorResponse(res, 500, 'Failed to update rule.', error.message);
  }
};

const deleteRule = async (req, res) => {
  try {
    const { communityId, ruleId } = req.params;
    const userId = req.user.id;

    const member = await CommunityMember.findOne({
      where: { community_id: communityId, user_id: userId },
    });
    if (!member || !['owner', 'admin'].includes(member.role)) {
      return errorResponse(res, 403, 'Only admins can delete rules.');
    }

    const rule = await CommunityRule.findOne({ where: { id: ruleId, community_id: communityId } });
    if (!rule) {
      return errorResponse(res, 404, 'Rule not found.');
    }

    await rule.destroy();

    return successResponse(res, 200, 'Rule deleted successfully.');
  } catch (error) {
    console.error('❌ Delete rule error:', error);
    return errorResponse(res, 500, 'Failed to delete rule.', error.message);
  }
};

// ─── 13. INVITE CODES & SHARED DIRECTORIES ─────────────────────
const getInviteLink = async (req, res) => {
  try {
    const { communityId } = req.params;
    const userId = req.user.id;

    const community = await Community.findByPk(communityId);
    if (!community) {
      return errorResponse(res, 404, 'Community not found.');
    }

    const member = await CommunityMember.findOne({
      where: { community_id: communityId, user_id: userId },
    });

    if (!member || (!community.settings.allowMemberInvites && !['owner', 'admin'].includes(member.role))) {
      return errorResponse(res, 403, 'You do not have permission to invite members.');
    }

    if (!community.invite_link) {
      const inviteCode = require('crypto').randomBytes(8).toString('hex');
      await community.update({ invite_link: inviteCode });
    }

    return successResponse(res, 200, 'Invite link fetched successfully.', {
      invite_code: community.invite_link,
    });
  } catch (error) {
    console.error('❌ Get invite link error:', error);
    return errorResponse(res, 500, 'Failed to fetch invite link.', error.message);
  }
};

const joinViaInviteLink = async (req, res) => {
  try {
    const { inviteCode } = req.params;
    const userId = req.user.id;

    const community = await Community.findOne({ where: { invite_link: inviteCode, is_active: true } });
    if (!community) {
      return errorResponse(res, 404, 'Invalid or expired community invite code.');
    }

    const member = await CommunityMember.findOne({
      where: { community_id: community.id, user_id: userId },
    });

    if (member) {
      if (member.is_banned) {
        return errorResponse(res, 403, 'You are banned from this community.');
      }
      return successResponse(res, 200, 'You are already a member of this community.', { community_id: community.id });
    }

    // Direct Join (even private accepts invite codes unless full)
    if (community.member_count >= community.max_members) {
      return errorResponse(res, 400, 'Community is full.');
    }

    await CommunityMember.create({
      community_id: community.id,
      user_id: userId,
      role: 'member',
    });

    await community.increment('member_count');

    return successResponse(res, 200, 'Joined community successfully.', { community_id: community.id });
  } catch (error) {
    console.error('❌ Join via link error:', error);
    return errorResponse(res, 500, 'Failed to join community.', error.message);
  }
};

const votePoll = async (req, res) => {
  try {
    const { communityId, postId } = req.params;
    const { optionIndex } = req.body;
    const userId = req.user.id;

    if (optionIndex === undefined || optionIndex === null) {
      return errorResponse(res, 400, 'Option index is required.');
    }

    const post = await CommunityPost.findOne({ where: { id: postId, community_id: communityId } });
    if (!post || post.type !== 'poll' || !post.poll) {
      return errorResponse(res, 404, 'Poll post not found.');
    }

    const pollData = { ...post.poll };
    if (!pollData.options || optionIndex < 0 || optionIndex >= pollData.options.length) {
      return errorResponse(res, 400, 'Invalid option index.');
    }

    const option = pollData.options[optionIndex];
    if (!option.votes) option.votes = [];
    
    pollData.options.forEach((opt, idx) => {
      if (!opt.votes) opt.votes = [];
      const userIdx = opt.votes.indexOf(userId);
      if (userIdx !== -1) {
        opt.votes.splice(userIdx, 1);
      }
    });

    const wasVoted = option.votes.indexOf(userId) !== -1;
    if (!wasVoted) {
      option.votes.push(userId);
    }

    await post.update({ poll: pollData });

    const io = req.app.get('io');
    if (io) {
      io.to(`community:${communityId}`).emit('community-poll-updated', {
        post_id: postId,
        poll: pollData,
      });
    }

    return successResponse(res, 200, 'Vote recorded successfully.', { poll: pollData });
  } catch (error) {
    console.error('❌ Vote poll error:', error);
    return errorResponse(res, 500, 'Failed to vote on poll.', error.message);
  }
};

const rsvpEvent = async (req, res) => {
  try {
    const { communityId, postId } = req.params;
    const userId = req.user.id;

    const post = await CommunityPost.findOne({ where: { id: postId, community_id: communityId } });
    if (!post || post.type !== 'event' || !post.event) {
      return errorResponse(res, 404, 'Event post not found.');
    }

    const eventData = { ...post.event };
    if (!eventData.attendees) eventData.attendees = [];

    const index = eventData.attendees.indexOf(userId);
    let attending = false;
    if (index === -1) {
      eventData.attendees.push(userId);
      attending = true;
    } else {
      eventData.attendees.splice(index, 1);
    }

    await post.update({ event: eventData });

    const io = req.app.get('io');
    if (io) {
      io.to(`community:${communityId}`).emit('community-event-updated', {
        post_id: postId,
        event: eventData,
      });
    }

    return successResponse(res, 200, attending ? 'RSVP registered.' : 'RSVP cancelled.', { event: eventData });
  } catch (error) {
    console.error('❌ RSVP event error:', error);
    return errorResponse(res, 500, 'Failed to RSVP to event.', error.message);
  }
};

module.exports = {
  createCommunity,
  discoverCommunities,
  searchCommunities,
  joinCommunity,
  leaveCommunity,
  getCommunity,
  getMyCommunities,
  updateCommunity,
  deleteCommunity,
  updateAvatar,
  updateCover,
  getMembers,
  updateMemberRole,
  banMember,
  unbanMember,
  getJoinRequests,
  approveRequest,
  rejectRequest,
  getChannels,
  createChannel,
  updateChannel,
  deleteChannel,
  getCommunityPosts,
  createPost,
  deletePost,
  likePost,
  pinPost,
  getRules,
  addRule,
  updateRule,
  deleteRule,
  getInviteLink,
  joinViaInviteLink,
  votePoll,
  rsvpEvent,
};
