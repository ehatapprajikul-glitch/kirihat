// Mobile Menu Toggle
function toggleMenu() {
    const nav = document.getElementById('mainNav');
    const btn = document.querySelector('.mobile-menu-btn');
    nav.classList.toggle('active');
    btn.classList.toggle('active');

    // Prevent body scroll when menu is open on mobile
    if (nav.classList.contains('active')) {
        document.body.style.overflow = 'hidden';
    } else {
        document.body.style.overflow = '';
    }
}

// Header Scroll Effect
let lastScroll = 0;
window.addEventListener('scroll', () => {
    const header = document.getElementById('header');
    const currentScroll = window.pageYOffset;

    if (currentScroll > 50) {
        header.classList.add('scrolled');
    } else {
        header.classList.remove('scrolled');
    }

    lastScroll = currentScroll;
});

// Smooth Scroll for Anchor Links
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));

        if (target) {
            // Close mobile menu if open
            const nav = document.getElementById('mainNav');
            const btn = document.querySelector('.mobile-menu-btn');
            nav.classList.remove('active');
            btn.classList.remove('active');
            document.body.style.overflow = '';

            // Smooth scroll to target
            target.scrollIntoView({
                behavior: 'smooth',
                block: 'start'
            });
        }
    });
});

// Close Mobile Menu When Clicking Outside
document.addEventListener('click', (e) => {
    const nav = document.getElementById('mainNav');
    const btn = document.querySelector('.mobile-menu-btn');

    if (nav.classList.contains('active') &&
        !nav.contains(e.target) &&
        !btn.contains(e.target)) {
        nav.classList.remove('active');
        btn.classList.remove('active');
        document.body.style.overflow = '';
    }
});

// Lazy Load Animation on Scroll
const observerOptions = {
    threshold: 0.1,
    rootMargin: '0px 0px -50px 0px'
};

const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry, index) => {
        if (entry.isIntersecting) {
            // Add staggered animation delay
            setTimeout(() => {
                entry.target.classList.add('visible');
            }, index * 100);
        }
    });
}, observerOptions);

// Observe elements for scroll animations
if (typeof IntersectionObserver !== 'undefined') {
    document.querySelectorAll('.feature-card, .stat-item, .step').forEach(el => {
        observer.observe(el);
    });
}

// Handle Window Resize
let resizeTimer;
window.addEventListener('resize', () => {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(() => {
        // Close mobile menu on desktop resize
        if (window.innerWidth > 768) {
            const nav = document.getElementById('mainNav');
            const btn = document.querySelector('.mobile-menu-btn');
            nav.classList.remove('active');
            btn.classList.remove('active');
            document.body.style.overflow = '';
        }
    }, 250);
});

// Prevent horizontal scroll on mobile
document.addEventListener('touchmove', (e) => {
    if (e.touches.length > 1) {
        e.preventDefault();
    }
}, { passive: false });

// Add visible class immediately for elements in viewport on page load
window.addEventListener('load', () => {
    document.querySelectorAll('.feature-card, .stat-item, .step').forEach(el => {
        const rect = el.getBoundingClientRect();
        if (rect.top < window.innerHeight && rect.bottom > 0) {
            el.classList.add('visible');
        }
    });
});