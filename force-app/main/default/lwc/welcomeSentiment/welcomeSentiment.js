import { LightningElement, track } from 'lwc';

export default class WelcomeSentiment extends LightningElement {
    @track selectedSentiment = '';
    @track showMessage = false;

    sentiments = [
        { value: 'excellent', label: 'מעולה', emoji: '😊', color: '#2e844a' },
        { value: 'good', label: 'טוב', emoji: '🙂', color: '#4bca81' },
        { value: 'okay', label: 'בסדר', emoji: '😐', color: '#0176d3' },
        { value: 'notGreat', label: 'לא כל כך', emoji: '😕', color: '#fe9339' },
        { value: 'bad', label: 'רע', emoji: '😞', color: '#ea001e' }
    ];

    get sentimentMessage() {
        const messages = {
            excellent: 'מעולה! אנחנו שמחים לשמוע שיש לך יום נהדר! 🌟',
            good: 'נהדר! תודה ששיתפת איתנו. יום טוב המשך! ✨',
            okay: 'בסדר גמור. אנחנו כאן אם אתה צריך משהו! 💙',
            notGreat: 'מקווים שהיום ישתפר בקרוב. אנחנו כאן בשבילך! 🤗',
            bad: 'מצטערים לשמוע. זכור שאנחנו כאן לתמוך בך! 💪'
        };
        return messages[this.selectedSentiment] || '';
    }

    get messageColor() {
        const sentiment = this.sentiments.find(s => s.value === this.selectedSentiment);
        return sentiment ? sentiment.color : '#0176d3';
    }

    get messageStyle() {
        return `color: ${this.messageColor}; border-right: 4px solid ${this.messageColor};`;
    }

    handleSentimentClick(event) {
        const value = event.currentTarget.dataset.value;
        this.selectedSentiment = value;
        this.showMessage = true;
    }

    get showWelcome() {
        return !this.showMessage;
    }
}