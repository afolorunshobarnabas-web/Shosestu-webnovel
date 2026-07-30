-- ==========================================
-- SHOSETSU EXTENSION: Webnovel (Mobile API)
-- ==========================================

-- Extension Metadata
-- Required global variables for Shosetsu listing mapping
id = "en.webnovel"
name = "Webnovel"
baseUrl = "https://m.webnovel.com"
language = "en"

-- Dependencies
-- Shosetsu provides a global 'http' client and a 'json' module for response parsing
local json = require("json")

--- 1. POPULAR / DISCOVER NOVELS
-- Fetches the default listing when browsing the extension source page
function getPopularNovels(page)
    -- Using the Webnovel mobile ranking API endpoint
    local url = "https://webnovel.com" .. page
    local response = http.get(url)
    
    if not response then return {} end
    local data = json.decode(response)
    local novels = {}
    
    -- Iterate through the items and build Shosetsu expected object structure
    if data and data.data and data.data.rankInfo and data.data.rankInfo.bookList then
        for _, book in ipairs(data.data.rankInfo.bookList) do
            table.insert(novels, {
                name = book.bookName,
                -- Map the specific novel page absolute link
                link = baseUrl .. "/book/" .. book.bookId,
                -- Formulate the cover image CDN URL using Webnovel's dynamic sizing pattern
                coverUrl = "https://webnovel.com" .. book.bookId .. "/600/600.jpg"
            })
        end
    end
    return novels
end

--- 2. SEARCH FUNCTIONALITY
-- Triggered when the user runs a query inside the search bar
function searchNovels(query, page)
    -- Webnovel mobile search API route
    local encodedQuery = http.urlEncode(query)
    local url = string.format("https://webnovel.com", encodedQuery, page)
    local response = http.get(url)
    
    if not response then return {} end
    local data = json.decode(response)
    local novels = {}
    
    if data and data.data and data.data.searchInfo and data.data.searchInfo.bookList then
        for _, book in ipairs(data.data.searchInfo.bookList) do
            table.insert(novels, {
                name = book.bookName,
                link = baseUrl .. "/book/" .. book.bookId,
                coverUrl = "https://webnovel.com" .. book.bookId .. "/600/600.jpg"
            })
        end
    end
    return novels
end

--- 3. NOVEL DETAILS & CHAPTER LISTING
-- Extracts full description, status, and the complete chapter index array
function getNovelDetails(novelUrl)
    -- Extract the unique bookId using a simple string pattern match
    local bookId = string.match(novelUrl, "book/(%d+)")
    if not bookId then return nil end
    
    -- API call to fetch the Table of Contents (TOC) metadata
    local url = "https://webnovel.com" .. bookId
    local response = http.get(url)
    
    if not response then return nil end
    local data = json.decode(response)
    
    local details = {
        name = "",
        description = "No description available.",
        coverUrl = "https://webnovel.com" .. bookId .. "/600/600.jpg",
        author = "Unknown",
        status = "Unknown",
        chapters = {}
    }
    
    if data and data.data then
        -- Set specific book details if returned by metadata
        if data.data.bookInfo then
            details.name = data.data.bookInfo.bookName or ""
            details.author = data.data.bookInfo.authorName or "Unknown"
            details.description = data.data.bookInfo.description or details.description
        end
        
        -- Build the list of individual chapters
        if data.data.volumeItems then
            for _, volume in ipairs(data.data.volumeItems) do
                if volume.chapterItems then
                    for _, chap in ipairs(volume.chapterItems) do
                        table.insert(details.chapters, {
                            name = chap.chapterName,
                            -- Link structure passed later directly into getChapterContent
                            link = baseUrl .. "/book/" .. bookId .. "/" .. chap.chapterId,
                            -- Order index
                            index = chap.chapterIndex
                        })
                    end
                end
            end
        end
    end
    return details
end

--- 4. CHAPTER CONTENT EXTRACTION
-- Fetches the textual body structure of a chosen chapter
function getChapterContent(chapterUrl)
    local bookId, chapterId = string.match(chapterUrl, "book/(%d+)/(%d+)")
    if not bookId or not chapterId then return "Error: Invalid chapter path parameters." end
    
    local url = string.format("https://webnovel.com", bookId, chapterId)
    local response = http.get(url)
    
    if not response then return "Error: Failed to fetch chapter body." end
    local data = json.decode(response)
    
    local paragraphTexts = {}
    
    if data and data.data and data.data.chapterInfo and data.data.chapterInfo.contents then
        for _, para in ipairs(data.data.chapterInfo.contents) do
            -- Filter text bodies and stack arrays safely
            if para.content and para.content ~= "" then
                table.insert(paragraphTexts, "<p>" .. para.content .. "</p>")
            end
        end
    end
    
    -- Return text as a single structured HTML block as expected by Shosetsu
    return table.concat(paragraphTexts, "\n")
end
