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
    const totalPages = pagination.totalPages || pagination.totalPage || 0;
    const currentPage = pagination.page || 1;
    
    return res.status(200).json({
        success: true,
        message,
        data,
        pagination: {
            currentPage: currentPage,
            totalPages: totalPages,
            totalItems: pagination.totalItems || 0,
            itemsPerPage: pagination.limit || pagination.itemsPerPage || 20,
            hasNextPage: pagination.hasNextPage !== undefined ? pagination.hasNextPage : (currentPage < totalPages),
            hasPreviousPage: pagination.hasPreviousPage !== undefined ? pagination.hasPreviousPage : (currentPage > 1),
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