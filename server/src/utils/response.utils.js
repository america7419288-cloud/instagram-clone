const successResponse = (res, statusCode = 200, message, data = {}) => {
    return res.status(statusCode).json({
        success: true,
        message,
        data,
        timestamp: new Date().toISOString(),
    });
};

const errorResponse = (res, statusCode = 500, message, errors = null) => 
{
    return res.status(statusCode).json({
        success: false,
        message,
        ...(errors && { errors }),
        timestamp: new Date().toISOString(),
    });
};


const paginatedResponse = (res, message, data, pagination) => {
    return res.status(200).json({
        success: true,
        message,
        data,
        pagination: {
            currentPage: pagination.page,
            totalPage: pagination.totalPage,
            totalItems: pagination.totalItems,
            itemsPerPage: pagination.page < pagination.totalPage,
            hasNextPage: pagination.page > 1,
            nextCursor: pagination.nextCursor || null,
        },
        timestamp: new Date().toISOString(),
    });
};

module.exports = {
    successResponse,
    errorResponse,
    paginatedResponse,
};