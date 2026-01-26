// FAQ Page Functionality
document.addEventListener('DOMContentLoaded', function () {
    const faqItems = document.querySelectorAll('.faq-item');
    const categoryPills = document.querySelectorAll('.category-pill');
    const searchInput = document.getElementById('faqSearch');
    const searchBtn = document.querySelector('.search-btn');
    const categorySections = document.querySelectorAll('.faq-category-section');

    // Toggle FAQ Item
    faqItems.forEach(item => {
        const question = item.querySelector('.faq-question');

        question.addEventListener('click', () => {
            // Close other items in the same category (optional - remove if you want multiple open)
            const parentSection = item.closest('.faq-category-section');
            const siblingItems = parentSection.querySelectorAll('.faq-item');
            siblingItems.forEach(sibling => {
                if (sibling !== item && sibling.classList.contains('active')) {
                    sibling.classList.remove('active');
                }
            });

            // Toggle current item
            item.classList.toggle('active');
        });
    });

    // Category Filter
    categoryPills.forEach(pill => {
        pill.addEventListener('click', () => {
            const category = pill.getAttribute('data-category');

            // Update active pill
            categoryPills.forEach(p => p.classList.remove('active'));
            pill.classList.add('active');

            // Show/hide categories
            filterCategories(category);

            // Clear search
            if (searchInput) {
                searchInput.value = '';
                clearSearchHighlights();
            }
        });
    });

    // Filter categories based on selection
    function filterCategories(category) {
        categorySections.forEach(section => {
            const sectionCategory = section.getAttribute('data-category');

            if (category === 'all') {
                section.classList.remove('hidden');
            } else if (sectionCategory === category) {
                section.classList.remove('hidden');
            } else {
                section.classList.add('hidden');
            }
        });

        // Scroll to first visible section
        const firstVisible = document.querySelector('.faq-category-section:not(.hidden)');
        if (firstVisible) {
            firstVisible.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    }

    // Search Functionality
    if (searchInput) {
        searchInput.addEventListener('input', debounce(performSearch, 300));

        if (searchBtn) {
            searchBtn.addEventListener('click', performSearch);
        }

        searchInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                performSearch();
            }
        });
    }

    function performSearch() {
        const searchTerm = searchInput.value.toLowerCase().trim();

        // Clear previous highlights
        clearSearchHighlights();

        if (searchTerm === '') {
            // Show all categories
            categorySections.forEach(section => {
                section.classList.remove('hidden');
                const items = section.querySelectorAll('.faq-item');
                items.forEach(item => item.style.display = 'block');
            });

            // Reset to "All Questions" pill
            categoryPills.forEach(p => p.classList.remove('active'));
            document.querySelector('[data-category="all"]').classList.add('active');
            return;
        }

        let hasResults = false;

        // Search through all FAQ items
        categorySections.forEach(section => {
            section.classList.remove('hidden');
            const items = section.querySelectorAll('.faq-item');
            let sectionHasResults = false;

            items.forEach(item => {
                const question = item.querySelector('.faq-question').textContent.toLowerCase();
                const answer = item.querySelector('.faq-answer').textContent.toLowerCase();

                if (question.includes(searchTerm) || answer.includes(searchTerm)) {
                    item.style.display = 'block';
                    sectionHasResults = true;
                    hasResults = true;

                    // Highlight search term
                    highlightSearchTerm(item, searchTerm);

                    // Open the item if it contains the search term
                    item.classList.add('active');
                } else {
                    item.style.display = 'none';
                }
            });

            // Hide section if no results
            if (!sectionHasResults) {
                section.classList.add('hidden');
            }
        });

        // Show no results message if needed
        showNoResults(!hasResults);

        // Update active pill to "All Questions"
        categoryPills.forEach(p => p.classList.remove('active'));
        document.querySelector('[data-category="all"]').classList.add('active');
    }

    // Highlight search term in text
    function highlightSearchTerm(item, searchTerm) {
        const question = item.querySelector('.faq-question');
        const answer = item.querySelector('.faq-answer');

        // Highlight in question
        const questionText = question.childNodes[0].textContent;
        const questionHighlighted = questionText.replace(
            new RegExp(searchTerm, 'gi'),
            match => `<span class="highlight">${match}</span>`
        );
        question.childNodes[0].textContent = '';
        const span = document.createElement('span');
        span.innerHTML = questionHighlighted;
        question.insertBefore(span, question.firstChild);

        // Highlight in answer
        highlightInElement(answer, searchTerm);
    }

    // Recursive highlight in element
    function highlightInElement(element, searchTerm) {
        const walker = document.createTreeWalker(
            element,
            NodeFilter.SHOW_TEXT,
            null,
            false
        );

        const textNodes = [];
        while (walker.nextNode()) {
            textNodes.push(walker.currentNode);
        }

        textNodes.forEach(node => {
            const text = node.textContent;
            if (text.toLowerCase().includes(searchTerm)) {
                const highlightedText = text.replace(
                    new RegExp(searchTerm, 'gi'),
                    match => `<span class="highlight">${match}</span>`
                );
                const span = document.createElement('span');
                span.innerHTML = highlightedText;
                node.parentNode.replaceChild(span, node);
            }
        });
    }

    // Clear search highlights
    function clearSearchHighlights() {
        const highlights = document.querySelectorAll('.highlight');
        highlights.forEach(highlight => {
            const parent = highlight.parentNode;
            parent.replaceChild(document.createTextNode(highlight.textContent), highlight);
            parent.normalize();
        });
    }

    // Show/hide no results message
    function showNoResults(show) {
        let noResultsDiv = document.querySelector('.no-results');

        if (show && !noResultsDiv) {
            noResultsDiv = document.createElement('div');
            noResultsDiv.className = 'no-results show';
            noResultsDiv.innerHTML = `
                <span class="no-results-icon">🔍</span>
                <h3>No Results Found</h3>
                <p>We couldn't find any FAQs matching your search. Try different keywords or contact our support team.</p>
            `;
            document.querySelector('.faq-content .container').appendChild(noResultsDiv);
        } else if (!show && noResultsDiv) {
            noResultsDiv.remove();
        }
    }

    // Debounce function for search
    function debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }

    // Deep link to specific FAQ (if URL has hash)
    if (window.location.hash) {
        const hash = window.location.hash.substring(1);
        const targetItem = document.getElementById(hash);
        if (targetItem && targetItem.classList.contains('faq-item')) {
            setTimeout(() => {
                targetItem.classList.add('active');
                targetItem.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }, 500);
        }
    }

    // Add keyboard navigation
    document.addEventListener('keydown', (e) => {
        if (e.key === '/' && !searchInput.matches(':focus')) {
            e.preventDefault();
            searchInput.focus();
        }
    });
});