import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import de from '../public/locales/de/translation.json';

i18n
  .use(initReactI18next)
  .init({
    resources: {
      de: { translation: de },
    },
    lng: 'de', // default language
    fallbackLng: 'de',
    interpolation: {
      escapeValue: false, // react already safes from xss
    },
  });

export default i18n;
